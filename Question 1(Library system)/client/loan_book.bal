import ballerina/io;

function loanBookFlow() returns error? {
    boolean back = false;
    while !back {
        io:println("\nLOANS & BOOKINGS");
        io:println("1. Check if an asset is available");
        io:println("2. Loan an asset / Book a room or lab");
        io:println("3. Return an asset / End a booking");
        io:println("0. Back to main menu");

        match prompt("Select an option") {
            "1" => { checkAvailability(); }
            "2" => { finish(bookAsset()); }
            "3" => { returnAsset(); }
            "0" => { back = true; }
            _ => { io:println("Invalid option."); }
        }
    }
}

function checkAvailability() {
    string assetTag = prompt("Asset tag");
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }
    Asset? asset = fetchAsset(assetTag);
    if asset is Asset {
        io:println(asset.assetTag + " (" + asset.name + ") is " + availabilityLabel(asset) + ".");
    }
}

function bookAsset() returns error? {
    io:println("(Enter 0 at any prompt to cancel)");
    string assetTag = check ask("Asset tag to loan/book");
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }

    // Check first so the user is told straight away; the service checks again
    // when the booking is made, so two clients cannot both book the same asset.
    Asset? existing = fetchAsset(assetTag);
    if existing is () {
        return;
    }
    Asset current = existing;
    if current.status != "AVAILABLE" {
        io:println("Cannot loan/book " + assetTag + " - it is " + availabilityLabel(current) + ".");
        return;
    }

    io:println("Asset: " + current.name + " (" + current.institution + " - " + current.site + ") is AVAILABLE");
    string kind = (check ask("Type (LOAN for items / BOOKING for rooms and labs)")).toUpperAscii();
    if kind != "LOAN" && kind != "BOOKING" {
        io:println("Type must be LOAN or BOOKING.");
        return;
    }

    [int, json]|error result = httpPost("/assets/" + assetTag + "/book", {kind: kind});
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 || status == 201 {
        io:println(assetTag + " booked - now UNAVAILABLE.");
    } else {
        printApiError(status, body);
    }
}

function returnAsset() {
    string assetTag = prompt("Asset tag to return");
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }

    [int, json]|error result = httpPost("/assets/" + assetTag + "/return", {});
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 || status == 201 {
        io:println(assetTag + " returned - now AVAILABLE.");
    } else {
        printApiError(status, body);
    }
}

function availabilityLabel(Asset a) returns string {
    return a.status == "AVAILABLE" ? "AVAILABLE" : "UNAVAILABLE (" + a.status + ")";
}
