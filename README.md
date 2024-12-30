# sql_c3

A C3 SQL package, implementing an interface, types and utilities to handle SQL database connections.

Database drivers can implement the `sql::Driver` interface and register themselves with the `sql` module. The `sql` module can then be used to create a connection and execute queries.

It also contains a simple implementation of drivers for **PostgreSQL**, **MySQL** and **SQLite**.

**This project is WIP, use at your own risk.**

## Installing

- Clone the repository (with submodules to also get dependencies) and run the tests:

```sh
git clone --recurse-submodules https://github.com/louis77/sql_c3
cd sql_c3
c3c test
```

Make sure to change the linker paths in `project.json` to point to your `libpq`, `mysql-client` or `sqlite` installation.

## Supported databases

- [X] PostgreSQL (driver_id: `postgres`) (must install `libpq`)
- [X] MySQL 8+ (driver_id: `mysql`) (must install `mysql-client`)
- [X] SQLite 3+  (driver_id: `sqlite`) (must install `sqlite3`)
s
## Usage

This package contains the following modules:

- `sql` The user-facing interface
- `pg` Driver for PostgreSQL (based on `libpq`)
- `mysql8` Driver for MySQL 8.x (based on `mysql-client@8`)
- `sqlite` Driver for SQLite 3 (basen on `sqlite`)

The drivers are bindings for the respective databases. They can be used separately, if you want low-level access to the database system. Though, at the moment, the drivers are not complete, bindings might be missing. **Contributions are welcome**!

Generally, this is how you would use the `sql` module:

```kotlin
import sql;

fn void main()
{
    // Open a connection
    sql::Connection conn = sql::open("postgres", "postgres://postgres@localhost/postgres")!;
    defer try conn.close();

    // Make a simple query
    String cmd = "SELECT * FROM (VALUES(1, 'hello', null), (2, 'world', null)) AS t(a_num, a_string, a_null)";

    Result res = conn.query(cmd)!;
    defer res.close(); // Don't forget to close the result

    // Call next() to move to next row. Must also be called for the first row
    while (res.next()) {
        int a_num;
        String a_string;
        int* a_null; // supports checking for NULL

        // Scan each column into a variable.
        res.scan(0, &a_num)!;
        res.scan(1, &a_string)!;
        res.scan(2, &a_null)!;
    }
}
```

See the [test](test) folder for examples of how to use the `sql` module.

The `sql` package has the following API:

```kotlin
fn Connection! open(String driver_id, String connection_string);

// The driver_id is registered by the respective driver module.
// See the drivers section for how to register a driver.

interface Connection
{
    fn void         close();
    fn void!        ping();
    fn Result!      query(String command, args...);
    fn usz!         exec(String command, args...);
    fn String       last_error();

    // Optionally, start, commit or rollback transactions
    fn void!        tx_begin();
    fn void!        tx_commit();
    fn void!        tx_rollback();
    fn bool         tx_in_progress();
}

interface Result
{
    fn bool         next();
    fn void!        scan(int fieldnum, any dest);
}

fault Error
{
    CONNECTION_FAILURE,
    NOT_IMPLEMENTED,
    COMMAND_FAILED,
    PARAM_BINDING_FAILED,
    UNSUPPORTED_SCAN_TYPE,
    UNSUPPORTED_BIND_TYPE,
    ILLEGAL_COLUMN_ACCESS,
    PREPARE_FAILED,
    UNKNOWN_ERROR,
    TX_ALREADY_IN_PROGRESS,
}
```

### Query arguments

All supported drivers use parameter binding to safely pass arguments to queries. All types that implement the `Printable` interface are supported.

The SQL syntax to indicate parameters in a query depend on the database. For example, PostgreSQL uses `$1`, `$2` etc. For MySQL, use `?`. For SQLite, use `?`, `?N`, `:N`, `@N` or `$N` where `N` is the index of the parameter (starting at 1).

### Scanning results

The following types are supported for scanning destinations:

```
String
ZString
bool
int int128 long short ichar
uint uint128 ulong ushort char
double
float

String*
ZString*
bool*
int* int128* long* short* ichar*
uint* uint128* ulong* ushort* char*
double*
float*
```

If you scan into a pointer type, it will be set to `null` if the result was SQL `NULL`. Otherwise `NULL` will scan into an empty value.

Other types will currently return a `UNSUPPORTED_SCAN_TYPE` fault.

## Drivers

The drivers are implemented as `sql::Driver` objects. They are registered with the `sql` module and can be used with the `sql::open` function.

A driver is expected to register itself with the `sql` module using the `sql::register_driver` function:

```kotlin
fn void register_driver() @init @private {
    Postgres* db = mem::new(Postgres);
    sql::register_driver("postgres", db);
}
```

A driver must implement the `sql::Driver` interface, which contains a `free` method that will be called when the driver is unregistered on shutdown. The various driver modules provide for ample examples on how to implement a custom driver.

## Project status

The library is work in progress and is still missing a lot of features. Ultimately the plan is to make it fully usable for all your SQL needs.

Currently supported:

- [x] Connecting to a database
- [x] Execution of Queries and Statements
- [x] Scanning of result values into all native C3 types
- [x] Parameterized queries
- [x] Transactions

In progress:

- [ ] Fix some memory leaks
- [ ] Prepared statements (currently used internally, but not exposed to the user)
- [ ] Connection pooling
- [ ] Support for Custom scannable types (SQLValue)
- [ ] Support for DB specific types
- [ ] Use binary encoding of params/result values

On-demand:

- [ ] Multiple result sets
- [ ] Named parameters (i.e. used by MS SQL Servers)

## LICENSE

MIT. See [LICENSE](LICENSE).
