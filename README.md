# sql_c3

A C3 SQL package, implementing an interface, types and utilities to handle SQL database connections.

Database drivers can implement the `sql::Driver` interface and register themselves with the `sql` module. The `sql` module can then be used to create a connection and execute queries.

It also contains a simple implementation of a Driver for PostgreSQL (which is a wrapper around the libpq library).

**This project is WIP, use at your own risk.**

## Installing

Clone the repository and run `c3c build`. Run `c3c test` to run tests.

Make sure to change the linker paths in `project.json` to point to your `libpq` installation.

## Usage

See the `test/test_sql.c3` file for an example of how to use the `sql` module.

Generally, this is how you would use the `sql` module:

```c3
import sql;
import pg;

fn void main()
{
    Driver driver = pg::new_postgres();
    void* conn = driver.open("postgres://postgres@localhost/postgres");
    assert(driver.ping(conn) == true);
    driver.close(conn);
}
```

## LICENSE

MIT. See [LICENSE](LICENSE).
