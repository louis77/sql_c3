# sql_c3

A C3 SQL package, implementing an interface, types and utilities to handle SQL database connections.

Database drivers can implement the `sql::Driver` interface and register themselves with the `sql` module. The `sql` module can then be used to create a connection and execute queries.

It also contains a simple implementation of drivers for PostgreSQL and MySQL.

**This project is WIP, use at your own risk.**

## Installing

- Clone the following dependencies: 
  - [url_c3](https://github.com/louis77/url_c3)
- Clone the repository and modify `project.json` to include paths to the dependencies
- Execute `c3c test` to run tests

Make sure to change the linker paths in `project.json` to point to your `libpq` installation.


## Usage

This package contains two modules:

- `sql` The user-facing interface
- `pg` A driver for PostgreSQL (wraps `libpq`)
- `mysql8` A driver for MySQL 8.x (wraps `mysql-client@8`)

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
        String a_num;
        String a_string;
        String a_null;

        // Scan each column into a variable.
        res.scan(0, &a_num)!;
        res.scan(1, &a_string)!;
        res.scan(2, &a_null)!;
    }
}
```

See the [test/test_sql.c3](test/test_sql.c3) file for examples of how to use the `sql` module.


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
    fn Result!      query(String command);
    fn usz!         exec(String command);
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
    UNSUPPORTED_SCAN_TYPE,
}
```

### Scanning values

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

- [x] Single connection to a database
- [x] Execution of Queries and Statements
- [x] Scanning of result values into all supported C3 types

Not implemented yet:

- [ ] Proper memory handling
- [ ] No support for prepared statements
- [ ] No support for transactions
- [ ] No support for connection pooling
- [ ] No support for parameterized queries
- [ ] No support for named parameters
- [ ] No support for multiple result sets


## LICENSE

MIT. See [LICENSE](LICENSE).
