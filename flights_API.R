library(ambiorix)
library(data.table)
library(jsonlite)
library(DBI)
library(RSQLite)

sqlite_file <- "flights.sqlite"

init_db <- function() {
  con <- dbConnect(SQLite(), sqlite_file)
  dbExecute(con, "CREATE TABLE IF NOT EXISTS flights (
                   flight_id INTEGER PRIMARY KEY,
                   year INTEGER, month INTEGER, day INTEGER,
                   dep_time INTEGER, sched_dep_time INTEGER,
                   dep_delay INTEGER, arr_time INTEGER,
                   sched_arr_time INTEGER, arr_delay INTEGER,
                   carrier TEXT, flight INTEGER, tailnum TEXT,
                   origin TEXT, dest TEXT, air_time INTEGER,
                   distance INTEGER, hour INTEGER, minute INTEGER,
                   time_hour TEXT, delayed INTEGER)")
  dbDisconnect(con)
}

process_data <- function() {
  con <- dbConnect(SQLite(), sqlite_file)
  existing_count <- dbGetQuery(con, "SELECT COUNT(*) AS count FROM flights")$count
  if (existing_count == 0) {
    flights_dt <- as.data.table(nycflights13::flights)
    flights_dt[, `:=` (flight_id = .I, delayed = as.integer(dep_delay > 15))]
    dbWriteTable(con, "flights", flights_dt, append = TRUE, row.names = FALSE)
  }
  dbDisconnect(con)
}

load_data <- function() {
  con <- dbConnect(SQLite(), sqlite_file)
  flights_dt <- as.data.table(dbReadTable(con, "flights"))
  dbDisconnect(con)
  flights_dt
}

init_db()
process_data()

app <- Ambiorix$new()

# Home page (unchanged JSON response; can switch to HTML if desired)
app$get("/", function(req, res) {
  res$json(list(message = "Welcome to the Flights API"))
})

# POST /flight
app$post("/flight", function(req, res) {
  content_length <- as.integer(req$CONTENT_LENGTH)
  if (is.null(content_length) || content_length == 0) {
    res$send(jsonlite::toJSON(list(error = "Empty payload")), status = 400L)
    return(NULL)
  }
  
  body_raw <- tryCatch(req$rook.input$read(content_length), error = function(e) NULL)
  if (is.null(body_raw) || length(body_raw) == 0) {
    res$send(jsonlite::toJSON(list(error = "Empty payload")), status = 400L)
    return(NULL)
  }
  
  body_str <- tryCatch(rawToChar(body_raw), error = function(e) NULL)
  if (is.null(body_str) || nchar(body_str) == 0) {
    res$send(jsonlite::toJSON(list(error = "Invalid payload format")), status = 400L)
    return(NULL)
  }
  
  new_flight <- tryCatch(as.data.table(fromJSON(body_str)), error = function(e) NULL)
  if (is.null(new_flight)) {
    res$send(jsonlite::toJSON(list(error = "Invalid JSON")), status = 400L)
    return(NULL)
  }
  
  flights_dt <- load_data()
  new_flight[, flight_id := max(flights_dt$flight_id, na.rm = TRUE) + 1]
  common_cols <- intersect(names(flights_dt), names(new_flight))
  
  con <- dbConnect(SQLite(), sqlite_file)
  dbWriteTable(con, "flights", new_flight[, ..common_cols], append = TRUE, row.names = FALSE)
  dbDisconnect(con)
  
  res$json(list(message = "Flight added", flight_id = new_flight$flight_id))
})

# GET /flight/:id (Fixed to return a single object)
app$get("/flight/:id", function(req, res) {
  con <- dbConnect(SQLite(), sqlite_file)
  flight <- dbGetQuery(con, "SELECT * FROM flights WHERE flight_id = ?", params = list(as.integer(req$params$id)))
  dbDisconnect(con)
  if (nrow(flight) == 0) {
    res$send(jsonlite::toJSON(list(error = "Flight not found")), status = 404L)
    return(NULL)
  }
  # Convert the single row to a named list
  flight_row <- as.list(flight[1, ])
  res$json(flight_row)
})
# GET /check-delay/:id
app$get("/check-delay/:id", function(req, res) {
  # Validate flight_id
  flight_id <- suppressWarnings(as.integer(req$params$id))
  if (is.na(flight_id) || flight_id <= 0) {
    res$send(jsonlite::toJSON(list(error = "Invalid flight ID: must be a positive integer")), status = 400L)
    return(NULL)
  }

  con <- NULL
  tryCatch({
    con <- dbConnect(SQLite(), sqlite_file)
    flight <- dbGetQuery(con, "SELECT delayed FROM flights WHERE flight_id = ?", params = list(flight_id))
    if (nrow(flight) == 0) {
      res$send(jsonlite::toJSON(list(error = sprintf("Flight with ID %d not found", flight_id))), status = 404L)
      return(NULL)
    }
    res$json(list(delayed = flight$delayed[1]))
  }, error = function(e) {
    res$send(jsonlite::toJSON(list(error = sprintf("Database error: %s", e$message))), status = 500L)
    return(NULL)
  }, finally = {
    if (!is.null(con) && dbIsValid(con)) {
      dbDisconnect(con)
    }
  })
})

# GET /avg-dep-delay
app$get("/avg-dep-delay", function(req, res) {
  airline <- req$query$id
  
  # Validate airline parameter if provided
  if (!is.null(airline) && (nchar(airline) == 0 || !grepl("^[A-Za-z0-9]+$", airline))) {
    res$send(jsonlite::toJSON(list(error = "Invalid airline code: must be non-empty alphanumeric")), status = 400L)
    return(NULL)
  }

  con <- NULL
  tryCatch({
    con <- dbConnect(SQLite(), sqlite_file)
    if (is.null(airline) || nchar(airline) == 0) {
      avg_dep_delay <- dbGetQuery(con, "SELECT carrier, AVG(dep_delay) AS avg_delay FROM flights GROUP BY carrier")
      if (nrow(avg_dep_delay) == 0) {
        res$send(jsonlite::toJSON(list(error = "No flight data available")), status = 404L)
        return(NULL)
      }
    } else {
      avg_dep_delay <- dbGetQuery(con, "SELECT carrier, AVG(dep_delay) AS avg_delay FROM flights WHERE carrier = ? GROUP BY carrier", params = list(airline))
      if (nrow(avg_dep_delay) == 0) {
        res$send(jsonlite::toJSON(list(error = sprintf("Airline '%s' not found", airline))), status = 404L)
        return(NULL)
      }
    }
    res$json(as.list(avg_dep_delay))
  }, error = function(e) {
    res$send(jsonlite::toJSON(list(error = sprintf("Database error: %s", e$message))), status = 500L)
    return(NULL)
  }, finally = {
    if (!is.null(con) && dbIsValid(con)) {
      dbDisconnect(con)
    }
  })
})

# GET /top-destinations/:n
app$get("/top-destinations/:n", function(req, res) {
  n <- suppressWarnings(as.integer(req$params$n))
  if (is.na(n) || n <= 0) {
    res$send(jsonlite::toJSON(list(error = "Invalid number")), status = 400L)
    return(NULL)
  }
  
  con <- dbConnect(SQLite(), sqlite_file)
  top_dest <- dbGetQuery(con, "SELECT dest, COUNT(*) AS count FROM flights GROUP BY dest ORDER BY count DESC LIMIT ?", params = list(n))
  dbDisconnect(con)
  res$json(as.list(top_dest))
})

# PUT /flights/:id
app$put("/flights/:id", function(req, res) {
  content_length <- as.integer(req$CONTENT_LENGTH)
  if (is.null(content_length) || content_length == 0) {
    res$send(jsonlite::toJSON(list(error = "Empty payload")), status = 400L)
    return(NULL)
  }
  
  body_raw <- tryCatch(req$rook.input$read(content_length), error = function(e) NULL)
  if (is.null(body_raw) || length(body_raw) == 0) {
    res$send(jsonlite::toJSON(list(error = "Empty payload")), status = 400L)
    return(NULL)
  }
  
  body_str <- tryCatch(rawToChar(body_raw), error = function(e) NULL)
  if (is.null(body_str) || nchar(body_str) == 0) {
    res$send(jsonlite::toJSON(list(error = "Invalid payload format")), status = 400L)
    return(NULL)
  }
  
  updated_flight <- tryCatch(as.data.table(fromJSON(body_str)), error = function(e) NULL)
  if (is.null(updated_flight)) {
    res$send(jsonlite::toJSON(list(error = "Invalid JSON")), status = 400L)
    return(NULL)
  }
  
  con <- dbConnect(SQLite(), sqlite_file)
  flight_exists <- dbGetQuery(con, "SELECT 1 FROM flights WHERE flight_id = ?", params = list(as.integer(req$params$id)))
  if (nrow(flight_exists) == 0) {
    dbDisconnect(con)
    res$send(jsonlite::toJSON(list(error = "Flight not found")), status = 404L)
    return(NULL)
  }
  for (col in names(updated_flight)) {
    dbExecute(con, sprintf("UPDATE flights SET %s = ? WHERE flight_id = ?", col), params = list(updated_flight[[col]], as.integer(req$params$id)))
  }
  dbDisconnect(con)
  
  res$json(list(message = "Flight updated"))
})

# DELETE /:id
app$delete("/:id", function(req, res) {
  con <- dbConnect(SQLite(), sqlite_file)
  result <- dbExecute(con, "DELETE FROM flights WHERE flight_id = ?", params = list(as.integer(req$params$id)))
  dbDisconnect(con)
  if (result == 0) {
    res$send(jsonlite::toJSON(list(error = "Flight not found")), status = 404L)
    return(NULL)
  }
  res$json(list(message = "Flight deleted"))
})

app$start(host = "0.0.0.0", port = 8000)