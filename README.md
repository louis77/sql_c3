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

Make sure to change the linker paths in `project.json` to point to your `libpq` and `mysql-client` installation.

## Supported databases

- [X] PostgreSQL (must install `libpq`)
- [X] MySQL 8+ (must install `mysql-client`)
- [X] SQLite 3+  (must install `sqlite3`)

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
import pg;

fn void main()
{
    // First load the driver
    Driver driver = pg::new_driver();
    defer pg::free_driver(driver);

    // Open a connection
    void* conn = driver.open("postgres://postgres@localhost/postgres");
    defer driver.close(conn);

    // Make a simple query
    String cmd = "SELECT * FROM (VALUES(1, 'hello', null), (2, 'world', null)) AS t(a_num, a_string, a_null)";
    Result res = conn.query(cmd)!;

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
interface Driver
{
    fn Connection!  open(String connection_string);
    fn void         close(Connection conn);
    fn void!        ping(Connection conn);
}

interface Connection
{
    fn Result!      query(String command, args...);
    fn usz!         exec(String command, args...);
    fn String       last_error();
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

## Limitations

The library is work in progress and is still missing a lot of features. Ultimately the plan is to make it fully usable for all your SQL needs.

Currently supported:

- [x] Connecting to a database
- [x] Execution of Queries and Statements
- [x] Scanning of result values into all native C3 types
- [x] Parameterized queries

In progress:

- [ ] Proper memory handling
- [ ] Prepared statements
- [ ] Transactions
- [ ] Connection pooling
- [ ] Named parameters
- [ ] Multiple result sets


## LICENSE

MIT. See [LICENSE](LICENSE).
