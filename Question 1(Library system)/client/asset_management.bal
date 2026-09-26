import ballerina/io;
function printAssetMenu() {
    io:println("\nASSET MANAGEMENT MENU");
    io:println("1. Create asset");
    io:println("2. View one asset");
    io:println("3. Update asset");
    io:println("4. Delete asset");
    io:println("5. View all assets");
    io:println("0. Back to main menu");
}

function assetManagementMenu() returns error? {
    boolean running = true;
    while running {
        printAssetMenu();
        string choice = io:readln("Select an option: ").trim();
        match choice {
            "1" => { finish(createAssetFlow()); }
            "2" => { check viewAssetFlow(); }
            "3" => { finish(updateAssetFlow()); }
            "4" => { check deleteAssetFlow(); }
            "5" => { check viewAllAssetsFlow(); }
            "0" => { running = false; }
            _ => { io:println("Invalid option, please try again."); }
        }
    }
}

function createAssetFlow() returns error? {
    io:println("\n-- New asset (0 to cancel) --");
    string assetTag = check ask("Asset tag");
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }
    string name = check ask("Name");
    string description = check ask("Description");
    string institution = check selectInstitution();
    string site = check ask("Site / location");
    string dateAcquired = check promptDate("Date acquired");

    Asset newAsset = {
        assetTag: assetTag,
        name: name,
        description: description,
        institution: institution,
        site: site,
        status: "AVAILABLE",
        dateAcquired: dateAcquired
    };

    [int, json]|error result = httpPost("/assets", newAsset.toJson());
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 || status == 201 {
        io:println("Asset '" + assetTag + "' (" + name + ") was created successfully.");
    } else {
        io:println("Asset was NOT created.");
        printApiError(status, body);
    }
}


function viewAssetFlow() returns error? {
    string assetTag = io:readln("Enter asset tag: ");

    Asset? asset = fetchAsset(assetTag);
    if asset is Asset {
        printAssetDetail(asset);
    }
}

function viewAllAssetsFlow() returns error? {
    [int, json]|error result = httpGet("/assets");
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [status, body] = result;
    if status != 200 {
        printApiError(status, body);
        return;
    }

    Asset[]|error assets = body.cloneWithType();
    if assets is error {
        io:println("Failed to parse assets: " + assets.message());
        return;
    }

    io:println("\nAll Assets (" + assets.length().toString() + " total)");
    printAssetList(assets);
}

function updateAssetFlow() returns error? {
    io:println("(Enter 0 at any prompt to cancel)");
    string assetTag = check ask("Enter asset tag to update");
    Asset? existing = fetchAsset(assetTag);
    if existing is () {
        return;
    }
    Asset current = existing;

    io:println("Press Enter to keep the current value shown in [brackets].");
    string name = check askWithDefault("Name", current.name);
    string description = check askWithDefault("Description", current.description);
    string institution = check selectInstitution(current.institution);
    string site = check askWithDefault("Site", current.site);
    string status = check selectStatus(current.status);

    string dateAcquired = check promptDate("Date acquired", isoToDdmmyyyy(current.dateAcquired));

    // Components, schedules and work orders are left out so the service keeps
    // the ones already stored against the asset.
    json payload = {
        assetTag: assetTag,
        name: name,
        description: description,
        institution: institution,
        site: site,
        status: status,
        dateAcquired: dateAcquired
    };

    [int, json]|error result = httpPut("/assets/" + assetTag, payload);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [statusCode, body] = result;
    if statusCode == 200 {
        io:println("Asset '" + assetTag + "' was updated successfully.");
    } else {
        io:println("Asset was NOT updated.");
        printApiError(statusCode, body);
    }
}

function deleteAssetFlow() returns error? {
    string assetTag = prompt("Enter asset tag to delete");
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }

    [int, json]|error result = httpDelete("/assets/" + assetTag);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        io:println("Asset '" + assetTag + "' was deleted successfully.");
    } else {
        io:println("Asset was NOT deleted.");
        printApiError(status, body);
    }
}

final string[] & readonly ASSET_STATUSES = ["AVAILABLE", "LOANED_OUT", "OCCUPIED", "UNDER_MAINTENANCE", "DISPOSED"];

// Pick a status by number instead of typing it. Enter keeps the current one.
function selectStatus(string current) returns string|CancelError {
    io:println("Status (0 to cancel):");
    foreach int i in 0 ..< ASSET_STATUSES.length() {
        io:println("  " + (i + 1).toString() + ". " + ASSET_STATUSES[i]);
    }
    while true {
        string entered = check ask("Select status number [" + current + "]");
        if entered.length() == 0 {
            return current;
        }
        int|error choice = int:fromString(entered);
        if choice is int && choice >= 1 && choice <= ASSET_STATUSES.length() {
            return ASSET_STATUSES[choice - 1];
        }
        io:println("Please enter a number from 1 to " + ASSET_STATUSES.length().toString() + ".");
    }
}
