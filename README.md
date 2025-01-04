# sql_c3

A C3 SQL package, implementing an interface, types and utilities to handle SQL connections across different database vendors in a unified way.

Database drivers can implement the `sql::Driver` interface and register themselves with the `sql` module. The `sql` module can then be used to create a connection and execute queries.

The database bindings have contributed to the [C3 vendor](https://github.com/c3lang/vendor) project. See [Installing](#installing) for instructions how to obtain them.

**This project is WIP, use at your own risk.**

## <a name="installing"></a>Installing

- Make sure you have the latest C3 compiler installed (0.6.6+)
- Clone the repository
- Fetch project dependencies
- Optionally, run the tests

```sh
git clone https://github.com/louis77/sql_c3
cd sql_c3

# Get bindings for pq, mysql8 and sqlite3 from vendor library
c3c project fetch

# Run tests
c3c test

# Run tests with memory leak check
c3c test -D MEMCHECK
```

Make sure to change the linker paths in `project.json` to point to your `libpq`, `mysql-client` or `sqlite` installation.

## Supported databases

- [X] PostgreSQL (driver_id: `postgres`) (must install `libpq`)
- [X] MySQL 8+ (driver_id: `mysql`) (must install `mysql-client`)
- [X] SQLite 3+  (driver_id: `sqlite`) (must install `sqlite3`)

## Usage

This package contains the following modules:

- `sql` The user-facing interface
- `pg` Driver implementation for PostgreSQL (based on `libpq`)
- `mysql8` Driver implementation for MySQL 8.x (based on `mysql-client@8`)
- `sqlite3` Driver implementation for SQLite 3 (basen on `sqlite3`)

The driver implementations are based on the bindings for the respective databases.

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
		res.scan(a_num, a_string, a_null)!;
	}
}
```

See the [test](test) folder for further examples of how to use the `sql` module.

## Connection Pool

There is a simple implementation of a connection pool available. A pool starts a seperate thread that handles the expiration of unused connections. So your platform must either support POSIX threads or Windows.

Usage:

```kotlin

// Instead of a connection, create a pool.
// You pass the maximum number of connections and the expiration
// time of unused connection.

sql::Pool pool = sql::create_pool("postgres", "postgres://postgres@localhost/postgres",
	16, // maximum open connections
	1000 * time::MS // idle timeout
	)!;
defer try pool.free();

// Now you can acquire a new connection.
// If the pool is full, it throws a sql::Error.POOL_EXHAUSTED fault

sql::Connection conn = pool.acquire()!;

[... do some work ...]

pool.release(conn)!;

// After a connection is released, it will be kept open
// until the idle timeout is reached
```

⚠️ Due to a minor bug in C3 <= 0.6.5, pools leak a little bit of memory. This has been [fixed in C3 0.6.6+](https://github.com/c3lang/c3c/commit/5e32c8a828468892f8d9ab4fb95b595c25c6e72d).

## API

The `sql` package has the following API:

```kotlin
// The driver_id is registered by the respective driver module.
// See the drivers section for how to register a custom driver.

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

fn Connection! open(String driver_id, String connection_string);

struct Pool {}

fn Pool!        create_pool(String driver_id, String connection_string, usz max_open_conns, Duration max_idle_timeout, Allocator allocator=allocator::heap());
fn void!        Pool.free();
fn Connection!  Pool.acquire();
fn void!        Pool.release(Connection conn);
fn usz          Pool.conns_pooled();
fn usz          Pool.conns_available();


interface Result
{
	fn usz			num_columns();
	fn bool         next();
	fn void!        scan(dests...);
	fn void!		scan_field(usz fieldnum, any dest);
	fn void         close();
}


interface Scannable
{
	fn void! 	 decode(ZString raw_value);
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
	POOL_EXHAUSTED,
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

Use the `Result.scan()` function to scan into any of these types.. If you scan into a pointer type, it will be set to `null` if the result was SQL `NULL`. Otherwise `NULL` will scan into an empty value.

Other types will currently return a `UNSUPPORTED_SCAN_TYPE` fault.

### Scanning into structs

The conveniece macro `Result.@scan_struct()` makes it possible to scan the whole row into a user-defined `struct`. It also provides two Tagged Attributes, that modify the scanning. Example:

```kotlin
// Define a struct
struct AccessKey {
	String group    @SqlName("grp");
	String key      @SqlOmit;
	String ts       @SqlName("updated_at");
	String name;
	String type;
}

fn void main()
{
	sql::Connection conn = sql::open("postgres", connection_string)!!;
	defer try conn.close();

	String cmd = `SELECT 'vt' as grp, '1234' as key, 'now' as updated_at, 'John' as name, 'person' as type`;
	Result! res = conn.query(cmd)!!;
	defer res.close();

	AccessKey ak;
	res.@scan_struct(ak)!!;
}
```

There are currently the following two attributes:

- `@SqlName(fieldname)` is the name of the column from your query that maps to this field. The default is the name of the struct field
- `@SqlOmit` will skip scanning into this field

### Scanning into custom types

Optionally, you can use your own types as scanning destinations by implementing the `decode()` function (see the `Scannable` interface). This would make it possible to implement i.e. scanning times, arrays, json fields etc.

Example:

```kotlin
struct MyScanner
{
	int  int_value;
	bool valid;
}

fn void! MyScanner.decode(&self, ZString raw_value) @dynamic
{
	int tmp = raw_value.str_view().to_int()!;
	self.int_value = tmp;
	self.valid = true;
}
```

If the raw_value was SQL `NULL`, the `decode()` function will not be called, so your type must be laid out appropriately.

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
- [x] Scanning into arbitrary custom types
- [x] Scanning into structs
- [x] Parameterized queries
- [x] Transactions
- [x] Connection pooling

In progress:

- [ ] Fix some memory leaks
- [ ] Support binding custom types
- [ ] Prepared statements (currently used internally, but not exposed to the user)
- [ ] Implement some DB specific types (i.e. pq arrays)
- [ ] Use binary encoding of params/result values

On-demand, because the currently supported databases (pq, mysql, sqlite) don't support these features:

- [ ] Multiple result sets
- [ ] Named parameters (i.e. used by MS SQL Servers)

## LICENSE

MIT. See [LICENSE](LICENSE).
