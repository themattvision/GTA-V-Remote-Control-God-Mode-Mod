// GTA Remote Bridge, modulo ScriptHook V per GTA V Legacy in Story Mode.
// Riceve soltanto azioni dirette e limitate dal bridge locale, le applica nel game
// thread e riporta lo stato effettivo. Non riceve hash native o comandi arbitrari.

#include "ScriptHookShim.h"

#include <algorithm>
#include <fstream>
#include <string>
#include <vector>

namespace {
    constexpr std::size_t maximumTrackedVehicles = 12;

    namespace Native {
        constexpr Hash playerID = 0x4F8644AF03D0E0D6;
        constexpr Hash playerPedID = 0xD80958FC74E988A6;
        constexpr Hash isPlayerControlOn = 0x49C32D60007AFA47;
        constexpr Hash getPlayerInvincible = 0xB721981B2B939E07;
        constexpr Hash setPlayerInvincible = 0x239528EACDC3E7DE;
        constexpr Hash doesEntityExist = 0x7239B21A38F536BA;
        constexpr Hash isEntityDead = 0x5F9532F3B5CC2551;
        constexpr Hash setEntityInvincible = 0x3882114BDE571AD4;
        constexpr Hash setEntityAsMissionEntity = 0xAD738C3085FE7E11;
        constexpr Hash setEntityAsNoLongerNeeded = 0xB736A491E64A32CF;
        constexpr Hash setEntityCleanupByEngine = 0x3910051CCECDB00C;
        constexpr Hash getVehiclePedIsIn = 0x9A9112A0FE9A4713;
    }

    enum class RequestAction {
        none,
        setGodMode,
        setWreckPreservation,
    };

    std::string lastRequestID;
    bool wreckPreservationEnabled = false;
    std::vector<Vehicle> trackedVehicles;

    std::string gameDirectory() {
        char executablePath[MAX_PATH] = {};
        GetModuleFileNameA(nullptr, executablePath, MAX_PATH);
        std::string path(executablePath);
        const std::string::size_type separator = path.find_last_of("\\/");
        return separator == std::string::npos ? "." : path.substr(0, separator);
    }

    std::string valueFor(const std::string& contents, const std::string& key) {
        const std::string prefix = key + "=";
        const std::string::size_type start = contents.find(prefix);
        if (start == std::string::npos) {
            return "";
        }
        const std::string::size_type valueStart = start + prefix.length();
        const std::string::size_type end = contents.find_first_of("\r\n", valueStart);
        return contents.substr(valueStart, end == std::string::npos ? std::string::npos : end - valueStart);
    }

    RequestAction readRequest(bool& enabled) {
        std::ifstream commandFile(gameDirectory() + "\\GTARemoteBridge.command");
        if (!commandFile.is_open()) {
            return RequestAction::none;
        }

        const std::string contents((std::istreambuf_iterator<char>(commandFile)), std::istreambuf_iterator<char>());
        const std::string requestID = valueFor(contents, "requestID");
        if (valueFor(contents, "version") != "1" ||
            requestID.empty() ||
            requestID == lastRequestID) {
            return RequestAction::none;
        }

        const std::string action = valueFor(contents, "action");
        const RequestAction requestAction = action == "setGodMode"
            ? RequestAction::setGodMode
            : action == "setWreckPreservation"
                ? RequestAction::setWreckPreservation
                : RequestAction::none;
        if (requestAction == RequestAction::none) {
            return RequestAction::none;
        }

        const std::string value = valueFor(contents, "enabled");
        if (value != "0" && value != "1") {
            return RequestAction::none;
        }

        enabled = value == "1";
        lastRequestID = requestID;
        return requestAction;
    }

    bool entityExists(Entity entity) {
        return ScriptHook::invoke<bool>(Native::doesEntityExist, entity);
    }

    void releaseVehicle(Vehicle vehicle) {
        if (!entityExists(vehicle)) {
            return;
        }
        ScriptHook::invokeVoid(Native::setEntityCleanupByEngine, vehicle, true);
        ScriptHook::invokeVoid(Native::setEntityAsNoLongerNeeded, &vehicle);
    }

    void releaseTrackedVehicles() {
        for (Vehicle vehicle : trackedVehicles) {
            releaseVehicle(vehicle);
        }
        trackedVehicles.clear();
    }

    void protectVehicle(Vehicle vehicle) {
        if (!entityExists(vehicle)) {
            return;
        }
        ScriptHook::invokeVoid(Native::setEntityAsMissionEntity, vehicle, true, true);
        ScriptHook::invokeVoid(Native::setEntityCleanupByEngine, vehicle, false);
    }

    void trackPlayerVehicle(Ped playerPed) {
        const Vehicle vehicle = ScriptHook::invoke<Vehicle>(Native::getVehiclePedIsIn, playerPed, false);
        if (!entityExists(vehicle)) {
            return;
        }

        if (std::find(trackedVehicles.begin(), trackedVehicles.end(), vehicle) == trackedVehicles.end()) {
            if (trackedVehicles.size() == maximumTrackedVehicles) {
                releaseVehicle(trackedVehicles.front());
                trackedVehicles.erase(trackedVehicles.begin());
            }
            trackedVehicles.push_back(vehicle);
        }
        protectVehicle(vehicle);
    }

    int preservedWreckCount() {
        trackedVehicles.erase(
            std::remove_if(trackedVehicles.begin(), trackedVehicles.end(), [](Vehicle vehicle) {
                return !entityExists(vehicle);
            }),
            trackedVehicles.end()
        );

        int destroyedVehicles = 0;
        for (Vehicle vehicle : trackedVehicles) {
            protectVehicle(vehicle);
            if (ScriptHook::invoke<bool>(Native::isEntityDead, vehicle, false)) {
                destroyedVehicles++;
            }
        }
        return destroyedVehicles;
    }

    void publishState(Player player) {
        const bool godModeEnabled = ScriptHook::invoke<bool>(Native::getPlayerInvincible, player);
        const int wreckCount = wreckPreservationEnabled ? preservedWreckCount() : 0;
        const std::string statePath = gameDirectory() + "\\GTARemoteBridge.state";
        const std::string temporaryPath = statePath + ".tmp";

        std::ofstream stateFile(temporaryPath, std::ios::trunc);
        if (!stateFile.is_open()) {
            return;
        }
        stateFile << "version=1\n";
        stateFile << "godMode=" << (godModeEnabled ? "1" : "0") << "\n";
        stateFile << "wreckPreservation=" << (wreckPreservationEnabled ? "1" : "0") << "\n";
        stateFile << "preservedWreckCount=" << wreckCount << "\n";
        stateFile.close();
        MoveFileExA(temporaryPath.c_str(), statePath.c_str(), MOVEFILE_REPLACE_EXISTING);
    }
}

void ScriptMain() {
    while (true) {
        const Player player = ScriptHook::invoke<Player>(Native::playerID);
        const Ped playerPed = ScriptHook::invoke<Ped>(Native::playerPedID);

        if (entityExists(playerPed) && ScriptHook::invoke<bool>(Native::isPlayerControlOn, player)) {
            bool requestedValue = false;
            switch (readRequest(requestedValue)) {
            case RequestAction::setGodMode:
                ScriptHook::invokeVoid(Native::setEntityInvincible, playerPed, requestedValue);
                ScriptHook::invokeVoid(Native::setPlayerInvincible, player, requestedValue);
                break;
            case RequestAction::setWreckPreservation:
                wreckPreservationEnabled = requestedValue;
                if (!wreckPreservationEnabled) {
                    releaseTrackedVehicles();
                }
                break;
            case RequestAction::none:
                break;
            }
            if (wreckPreservationEnabled) {
                trackPlayerVehicle(playerPed);
            }
            publishState(player);
        }

        scriptWait(250);
    }
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
    switch (reason) {
    case DLL_PROCESS_ATTACH:
        scriptRegister(module, ScriptMain);
        break;
    case DLL_PROCESS_DETACH:
        scriptUnregister(module);
        break;
    }
    return TRUE;
}
