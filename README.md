

# Flights API

Welcome to the Flights API, a lightweight RESTful service built with R and Ambiorix to manage and query flight data. This API allows you to create, retrieve, update, and delete flight entries, check delay status, calculate average departure delays, and find top destinations—all powered by SQLite for persistent storage. Crafted with cosmic curiosity, this project aims to make flight data exploration both fun and functional.

## Features
- **JSON-based**: All responses are returned in JSON format.
- **SQLite Backend**: Data is stored and queried dynamically from `flights.sqlite`.
- **Error Handling**: Robust validation and error responses for a smooth user experience.
- **Endpoints**: Supports POST, GET, PUT, and DELETE operations for flight management.

## Prerequisites
- **R**: Version 4.0.0 or higher.
- **R Packages**:
  - `ambiorix`
  - `data.table`
  - `jsonlite`
  - `DBI`
  - `RSQLite`
  - `nycflights13` (for initial data)

Install dependencies in R:
```R
install.packages(c("ambiorix", "data.table", "jsonlite", "DBI", "RSQLite", "nycflights13"))
```

## Setup
1. **Clone or Copy the Code**:
   - Save the provided script as `flights_api.R` in your working directory.

2. **Run the Script**:
   - Open R or RStudio, set your working directory (e.g., `setwd("/path/to/your/dir")`), and run:
     ```R
     source("flights_api.R")
     ```
   - The server starts on `http://0.0.0.0:8000`.

3. **Database**:
   - The script creates `flights.sqlite` in your working directory if it doesn’t exist and populates it with `nycflights13::flights` data on first run.

## API Endpoints

### **GET /**  
- **Description**: Returns a welcome message.
- **Response**: `{"message": "Welcome to the Flights API"}`
- **Status**: 200 OK

### **POST /flight**  
- **Description**: Creates a new flight entry.
- **Headers**: `Content-Type: application/json`
- **Body**: JSON with flight details (e.g., `year`, `carrier`, `origin`, `dest`).
- **Example**:
   ![POST Request](Screenshot from 2025-02-24 03-30-09.png)
   
- **Response**: `{"message": "Flight added", "flight_id": [new_id]}` (200 OK)
- **Errors**: 
  - 400: `{"error": "Empty payload"}`, `{"error": "Invalid JSON"}`

### **GET /flight/:id**  
- **Description**: Returns details of a flight by ID.
- **Example**: `GET /flight/4`
- **Response**: JSON object with flight details (200 OK)
   ![GET Request flight id](Screenshot from 2025-02-24 03-32-05.png)

### **GET /check-delay/:id**  
- **Description**: Returns whether a flight is delayed.
- **Example**: `GET /check-delay/90`
- **Response**: `{"delayed": 0}` (200 OK)
   ![GET Request check delay](Screenshot from 2025-02-24 03-32-40.png)

### **GET /avg-dep-delay?id=[airline]**  
- **Description**: Returns average departure delay for an airline or all airlines if no `id` is provided.
- **Examples**: 
  - `GET /avg-dep-delay?id=AA`
  - `GET /avg-dep-delay`
- **Response**: 
  - Single airline: `{"carrier": "AA", "avg_delay": 8.586}` (200 OK)
  - All airlines: `{"carrier": ["AA", "AS", ...], "avg_delay": [8.586, 5.804, ...]}` (200 OK)
- **Errors**: 
  - 400: `{"error": "Invalid airline code: must be non-empty alphanumeric"}`
  - 404: `{"error": "Airline 'ZZ' not found"}` or `{"error": "No flight data available"}`
  - 500: `{"error": "Database error: [message]"}`
     ![GET Request check AVG delay](Screenshot from 2025-02-24 03-32-53.png)

### **GET /top-destinations/:n**  
- **Description**: Returns the top `n` destinations by flight count.
- **Example**: `GET /top-destinations/3`
- **Response**: `{"dest": ["ORD", "ATL", "LAX"], "count": [17283, 17215, 16174]}` (200 OK)
- **Errors**: 400: `{"error": "Invalid number"}`
     ![GET Request Top n flights](Screenshot from 2025-02-24 03-31-41.png)
### **PUT /flights/:id**  
- **Description**: Updates a flight’s details.
- **Headers**: `Content-Type: application/json`
- **Body**: JSON with updated fields (e.g., `{"dep_delay": 30, "delayed": 1}`).
- **Example**: `PUT /flights/2`
- **Response**: `{"message": "Flight updated"}` (200 OK)
- **Errors**: 
  - 400: `{"error": "Empty payload"}`, `{"error": "Invalid JSON"}`
  - 404: `{"error": "Flight not found"}`
 ![PUT Request](Screenshot from 2025-02-24 03-31-06.png)
### **DELETE /:id**  
- **Description**: Deletes a flight by ID.
- **Example**: `DELETE /2`
- **Response**: `{"message": "Flight deleted"}` (200 OK)
- **Errors**: 404: `{"error": "Flight not found"}`
 ![DELETE Request](Screenshot from 2025-02-24 03-30-43.png)
## Testing with Postman
1. **Start the Server**: Run the script in R.
2. **Open Postman**:
   - Create a collection (e.g., "Flights API").
   - Add requests for each endpoint with the specified method, URL, headers, and body.
3. **Test Cases**:
   - Use the examples above.
   - Test error cases (e.g., invalid IDs, empty payloads) to verify error handling.

## License

This project is licensed under the MIT License - see below for details.

```
MIT License

Copyright (c) 2025 [Your Name or Organization]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### Notes
Coded with boundless wonder!
- **License**: MIT is included at the bottom, keeping it open and permissive.
- **Your Name**: Replace `[Your Name or Organization]` in the license with your actual name or entity.


