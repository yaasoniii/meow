import ballerina/grpc;
import ballerina/io;

function createSampleUsers(RentalServiceClient rentalClient) returns error? {
    Create_usersStreamingClient streamingClient = check rentalClient->create_users();

    User[] sampleUsers = [
        {userId: "USER001", firstName: "Patrick", lastName: "Jane", email: "patrickjane@gmail.com", phoneNumber: "0812345678"},
        {userId: "USER002", firstName: "Bill", lastName: "Gates", email: "billgates@gmail.com", phoneNumber: "0818765432"},
        {userId: "USER003", firstName: "Michael", lastName: "Jackson", email: "mjackson@gmail.com", phoneNumber: "0818765234"}
    ];

    foreach User user in sampleUsers {
        check streamingClient->sendUser(user);
        io:println("Sent user: " + user.userId + "(" + user.firstName + " " + user.lastName + ")");
    }

    check streamingClient->complete();

    CreateUsersResponse? response = check streamingClient->receiveCreateUsersResponse();

    if response is CreateUsersResponse {
        io:println("\nCREATE USERS RESULT:");
        io:println("  Success       : " + response.success.toString());
        io:println("  Message       : " + response.message);
        io:println("  Users created : " + response.usersCreated.toString());
    } else {
        io:println("No response received from the server.");
    }

}

function addProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID: ").trim();
    string ownerId = io:readln("Owner (host) user ID: ").trim();
    string name = io:readln("Property name: ").trim();
    string description = io:readln("Description: ").trim();
    string location = io:readln("Location: ").trim();
    string propertyType = io:readln("Property type (e.g. Apartment, House): ").trim();
    int bedrooms = readRequiredInt("Number of bedrooms: ");
    float pricePerNight = readRequiredFloat("Price per night: ");

    Property property = {
        propertyId: propertyId,
        ownerId: ownerId,
        name: name,
        description: description,
        location: location,
        propertyType: propertyType,
        bedrooms: bedrooms,
        pricePerNight: pricePerNight,
        available: true
    };

    PropertyResponse response = check rentalClient->add_property({property: property});

    io:println("\nADD PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);
}

function browseAvailableProperties(RentalServiceClient rentalClient) returns error? {
    io:println("Leave any filter blank to skip it.");
    string location = io:readln("Filter by location: ").trim();
    string propertyType = io:readln("Filter by property type: ").trim();
    float minPrice = readOptionalFloat("Min price per night: ");
    float maxPrice = readOptionalFloat("Max price per night: ");
    int minBedrooms = readOptionalInt("Min bedrooms: ");

    stream<Property, grpc:Error?> propertyStream = check rentalClient->list_available_properties({
        location: location,
        propertyType: propertyType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minBedrooms: minBedrooms
    });

    io:println("\nAVAILABLE PROPERTIES BASED ON FILTERS:");
    int count = 0;

    record {|Property value;|}|grpc:Error? next = propertyStream.next();
    while next is record {|Property value;|} {
        Property p = next.value;
        if p.propertyId != "" {
            count += 1;
            io:println("  [" + p.propertyId + "] " + p.name + " - " + p.location +
                    " | " + p.bedrooms.toString() + " bed | N$" + p.pricePerNight.toString() + "/night");
        }
        next = propertyStream.next();
    }

    if next is grpc:Error {
        return next;
    }

    if count == 0 {
        io:println(" (No properties found based on the provided filters.)");
    }
}

function searchPropertyById(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to search for:").trim();

    SearchPropertyResponse response = check rentalClient->search_property({
        propertyId: propertyId
    });

    io:println("\nSEARCH RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);

    if response.properties.length() == 0 {
        io:println(" (no matching properties found)");
    } else {
        foreach Property p in response.properties {
            string availability = p.available ? "Available" : "Not Available";
            io:println(" [" + p.propertyId + "] " + p.name + "-" + p.location + " | " + p.bedrooms.toString() + " bed | N$" + p.pricePerNight.toString() + "/night | " + availability);
        }
    }
}

function updateProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to update: ").trim();

    // Load the current values so the user only changes what they pick.
    // Search only returns available properties; "Not Available" still tells
    // us the property exists (and that it is unavailable).
    SearchPropertyResponse found = check rentalClient->search_property({propertyId: propertyId});
    Property updated;
    boolean detailsKnown = false;
    if found.success && found.properties.length() > 0 {
        updated = found.properties[0].clone();
        detailsKnown = true;
    } else if found.message == "Not Available" {
        updated = {propertyId: propertyId, available: false};
        io:println("Property " + propertyId + " is currently not available, so its current details" +
                " can't be shown. Fields you don't change are kept.");
    } else {
        io:println("Property not found: " + propertyId);
        return;
    }

    boolean changed = false;
    while true {
        io:println("\nWhich section do you want to update?");
        io:println("1. Owner (host) user ID" + currentValue(detailsKnown, updated.ownerId));
        io:println("2. Property name" + currentValue(detailsKnown, updated.name));
        io:println("3. Description" + currentValue(detailsKnown, updated.description));
        io:println("4. Location" + currentValue(detailsKnown, updated.location));
        io:println("5. Property type" + currentValue(detailsKnown, updated.propertyType));
        io:println("6. Number of bedrooms" + currentValue(detailsKnown, updated.bedrooms.toString()));
        io:println("7. Price per night" + currentValue(detailsKnown, "N$" + updated.pricePerNight.toString()));
        io:println("8. Availability" + currentValue(true, updated.available ? "Available" : "Not Available"));
        io:println("9. Save changes");
        io:println("0. Cancel");

        match io:readln("Select an option: ").trim() {
            "1" => { updated.ownerId = readRequiredText("New owner (host) user ID: "); changed = true; }
            "2" => { updated.name = readRequiredText("New property name: "); changed = true; }
            "3" => { updated.description = readRequiredText("New description: "); changed = true; }
            "4" => { updated.location = readRequiredText("New location: "); changed = true; }
            "5" => { updated.propertyType = readRequiredText("New property type (e.g. Apartment, House): "); changed = true; }
            "6" => { updated.bedrooms = readPositiveInt("New number of bedrooms: "); changed = true; }
            "7" => { updated.pricePerNight = readPositiveFloat("New price per night: "); changed = true; }
            "8" => { updated.available = readRequiredBoolean("Available for booking? (y/n): "); changed = true; }
            "9" => {
                if !changed {
                    io:println("Nothing changed - property was NOT updated.");
                    return;
                }
                break;
            }
            "0" => {
                io:println("Update cancelled - property was NOT updated.");
                return;
            }
            _ => { io:println("Invalid option, please try again."); }
        }
    }

    PropertyResponse response = check rentalClient->update_property({
        propertyId: propertyId,
        property: updated
    });

    io:println("\nUPDATE PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);
}

function currentValue(boolean known, string value) returns string {
    return known ? " [" + value + "]" : "";
}

function removeProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to remove: ").trim();

    OperationResponse response = check rentalClient->remove_property({
        propertyId: propertyId
    });

    io:println("\nREMOVE PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);
}

function bookProperty(RentalServiceClient rentalClient) returns error? {
    string propertyId = io:readln("Property ID to book: ").trim();
    string userId = io:readln("Guest (user) ID: ").trim();
    string checkInDate = io:readln("Check-in date (YYYY-MM-DD): ").trim();
    string checkOutDate = io:readln("Check-out date (YYYY-MM-DD): ").trim();

    BookingResponse response = check rentalClient->book_property({
        propertyId: propertyId,
        userId: userId,
        checkInDate: checkInDate,
        checkOutDate: checkOutDate
    });

    io:println("\nBOOK PROPERTY RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);

    if response.success {
        io:println("  Booking ID : " + response.booking.bookingId);
        io:println("  Status     : " + response.booking.status);
        io:println("  (Use this Booking ID with 'Confirm a booking' to finalize it.)");
    }
}

function confirmBooking(RentalServiceClient rentalClient) returns error? {
    string bookingId = io:readln("Booking ID to confirm: ").trim();

    ConfirmBookingResponse response = check rentalClient->confirm_booking({
        bookingId: bookingId
    });

    io:println("\nCONFIRM BOOKING RESULT:");
    io:println("  Success : " + response.success.toString());
    io:println("  Message : " + response.message);

    if response.success {
        io:println("  Booking ID  : " + response.booking.bookingId);
        io:println("  Property ID : " + response.booking.propertyId);
        io:println("  Check-in    : " + response.booking.checkInDate);
        io:println("  Check-out   : " + response.booking.checkOutDate);
        io:println("  Status      : " + response.booking.status);
        io:println("  Total cost  : N$" + response.totalCost.toString());
    }
}

public function main() returns error? {
    RentalServiceClient rentalClient = check new ("http://localhost:9090", timeout = 5);

    boolean running = true;

    while running {
        io:println("\n=== RENTAL SYSTEM CLIENT MENU ===");
        io:println("1. Add a property");
        io:println("2. Update a property");
        io:println("3. Remove a property");
        io:println("4. Create sample users (streaming)");
        io:println("5. Browse available properties");
        io:println("6. Search property by ID");
        io:println("7. Book a property");
        io:println("8. Confirm a booking");
        io:println("9. Exit");

        string choice = io:readln("Select an option: ").trim();

        match choice {
            "1" => {
                check addProperty(rentalClient);
            }
            "2" => {
                check updateProperty(rentalClient);
            }
            "3" => {
                check removeProperty(rentalClient);
            }
            "4" => {
                check createSampleUsers(rentalClient);
            }
            "5" => {
                check browseAvailableProperties(rentalClient);
            }
            "6" => {
                check searchPropertyById(rentalClient);
            }
            "7" => {
                check bookProperty(rentalClient);
            }
            "8" => {
                check confirmBooking(rentalClient);
            }
            "9" => {
                running = false;
            }
            _ => {
                io:println("Invalid option, please try again.");
            }
        }
    }
}

function readOptionalFloat(string prompt) returns float {
    while true {
        string input = io:readln(prompt).trim();
        if input == "" {
            return 0.0;
        }
        float|error parsed = float:fromString(input);
        if parsed is float {
            return parsed;
        }
        io:println("  Invalid number, please try again or leave blank.");
    }
}

function readOptionalInt(string prompt) returns int {
    while true {
        string input = io:readln(prompt).trim();
        if input == "" {
            return 0;
        }
        int|error parsed = int:fromString(input);
        if parsed is int {
            return parsed;
        }
        io:println("  Invalid whole number, please try again or leave blank.");
    }
}

function readRequiredFloat(string prompt) returns float {
    while true {
        string input = io:readln(prompt).trim();
        float|error parsed = float:fromString(input);
        if parsed is float {
            return parsed;
        }
        io:println("  Invalid number, please try again (e.g. 950 or 950.50).");
    }
}

function readRequiredInt(string prompt) returns int {
    while true {
        string input = io:readln(prompt).trim();
        int|error parsed = int:fromString(input);
        if parsed is int {
            return parsed;
        }
        io:println("  Invalid whole number, please try again (e.g. 3).");
    }

}

function readRequiredBoolean(string prompt) returns boolean {
    while true {
        string input = io:readln(prompt).trim().toLowerAscii();
        if input == "y" || input == "yes" {
            return true;
        }
        if input == "n" || input == "no" {
            return false;
        }
        io:println("  Please answer y or n.");
    }
}


function readRequiredText(string prompt) returns string {
    while true {
        string input = io:readln(prompt).trim();
        if input != "" {
            return input;
        }
        io:println("  This field can't be blank, please try again.");
    }
}

function readPositiveInt(string prompt) returns int {
    while true {
        int value = readRequiredInt(prompt);
        if value > 0 {
            return value;
        }
        io:println("  Please enter a number greater than 0.");
    }
}

function readPositiveFloat(string prompt) returns float {
    while true {
        float value = readRequiredFloat(prompt);
        if value > 0.0 {
            return value;
        }
        io:println("  Please enter a number greater than 0.");
    }
}
