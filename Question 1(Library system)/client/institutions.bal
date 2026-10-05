import ballerina/io;


function institutionMenu() returns error? {
    boolean back = false;
    while !back {
        io:println("\n------------- INSTITUTION MANAGEMENT -------------");
        io:println("1. List institutions");
        io:println("2. Add institution");
        io:println("3. Remove institution");
        io:println("0. Back to main menu");
        string choice = prompt("Select an option");
        match choice {
            "1" => { listInstitutions(); }
            "2" => { finish(addInstitution()); }
            "3" => { removeInstitution(); }
            "0" => { back = true; }
            _ => { io:println("Invalid option."); }
        }
    }
}
//cloneWithType() turns raw JSON from the server side into a typed Ballerina
function listInstitutions() {
    [int, json]|error result = httpGet("/institutions"); //sends a request to the server
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        string[]|error names = body.cloneWithType();
        if names is string[] {
            io:println("\n-- Registered Institutions (" + names.length().toString() + ") --");
            foreach string n in names {
                io:println("  - " + n);
            }
        }
    } else {
        printApiError(status, body);
    }

}

function addInstitution() returns error? {
    io:println("(Enter 0 at any prompt to cancel)");
    string name = check ask("Institution name");
    json payload = {name: name}; //builds request body
    [int, json]|error result = httpPost("/institutions", payload);
    if result is error {
        io:println("Request failed: " + result.message()); //handles network failure
        return;
    }
    var [status, body] = result; //unpacks the answer
    if status == 200 {
        io:println("Institution added.");
    } else {
        printApiError(status, body);
    }
}

function removeInstitution() {
    string name = prompt("Institution name to remove");
    [int, json]|error result = httpDelete("/institutions/" + name);
    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }
    var [status, body] = result;
    if status == 200 {
        io:println("Institution removed.");
    } else {
        printApiError(status, body);
    }
}

// Lets the user pick one of the registered institutions by number instead of
// typing a name. With a current value (update), pressing Enter keeps it.
// 0 cancels; an error is returned if the list could not be loaded.
function selectInstitution(string? current = ()) returns string|error {
    [int, json]|error result = httpGet("/institutions");
    if result is error {
        return error("Could not load institutions: " + result.message());
    }
    var [status, body] = result;
    if status != 200 {
        return error("Could not load institutions (HTTP " + status.toString() + ").");
    }
    string[]|error names = body.cloneWithType();
    if names is error || names.length() == 0 {
        return error("No institutions registered. Add one under Institution Management first.");
    }

    io:println("Institution (0 to cancel):");
    foreach int i in 0 ..< names.length() {
        io:println("  " + (i + 1).toString() + ". " + names[i]); // print list accordingly
    }
    while true {
        string label = current is string
            ? "Select institution number [" + current + "]"
            : "Select institution number";
        string entered = check ask(label);
        if entered.length() == 0 && current is string {
            return current;
        }
        int|error choice = int:fromString(entered);
        if choice is int && choice >= 1 && choice <= names.length() {
            return names[choice - 1];
        }
        io:println("Please enter a number from 1 to " + names.length().toString() + ".");
    }
}
