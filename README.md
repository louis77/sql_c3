# sql_c3

A C3 SQL package, implementing an interface, types and utilities to handle SQL database connections.

Database drivers can implement the `sql::Driver` interface and register themselves with the `sql` module. The `sql` module can then be used to create a connection and execute queries.

It also contains a simple implementation of a Driver for PostgreSQL (which is a wrapper around the libpq library).

**This project is WIP, use at your own risk.**

## Installing

Clone the repository and run `c3c build`. Run `c3c test` to run tests.

Make sure to change the linker paths in `project.json` to point to your `libpq` installation.

## Usage

See the `test/test_sql.c3` file for examples of how to use the `sql` module.

Generally, this is how you would use the `sql` module:

```kotlin
import sql;
import pg;

fn void main()
{
    // First load the driver
    Driver driver = pg::new_postgres();
    defer pg::free_postgres(driver);

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

The `sql` package has the following API:

```kotlin
interface Driver 
{
    fn Connection!  open(String connection_string);
    fn void         close(Connection conn);
    fn void!        ping(String connection_string);
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
```

Other types will currently return a `UNSUPPORTED_SCAN_TYPE` fault.

## LICENSE

MIT. See [LICENSE](LICENSE).
