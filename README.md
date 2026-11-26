# httpserver (x86-64 assembly / FASM)

A small HTTP/1.1 server written in x86-64 assembly with the flat assembler.
It serves:

- **Static files** from `/var/www/html/`
- **PHP** (`.php` files and a directory's `index.php`) through PHP-FPM (FastCGI)
- **Compiled programs** — any file with the execute bit is run and its stdout/stderr
  becomes the response body (Rust, C, shell scripts, ...)
- **Shared libraries** (`.so`) — run through `/lib64/ld-linux-x86-64.so.2`

Tested on Arch Linux and Ubuntu 20.04. Listens on `0.0.0.0:8080`.

## Requirements

- flat assembler: <https://flatassembler.net/download.php>
- PHP-FPM (8.4 tested) for `.php` files

## Build

```bash
../fasm2/fasm2 httpserver.asm http
```

If `http` is currently running, Linux refuses to overwrite the running executable
and fasm prints `Error: failed to write the output file` (ETXTBSY). Either stop
the server first, or build to a temporary name and replace it atomically:

```bash
../fasm2/fasm2 httpserver.asm http.new && mv -f http.new http
```

Restart the server afterwards to run the new binary.

## Run

```bash
sudo ./http        # recommended: drops privileges to www-data (uid 33)
# or without root:
./http
```

Then open <http://127.0.0.1:8080/>. Files are served from `/var/www/html/`.

## Configuration (`server.conf`)

The server reads `server.conf` **once at startup**, from the directory it is
started in (its working directory). If the file is missing, the built-in
defaults below are used. Edit the file and restart the server to apply changes.
A template containing every supported key is provided as `server.conf.example`.

```ini
# all values are in bytes; 0 = unlimited
max_php_response_size=1048576    # max PHP/FastCGI response body
max_static_file_size=8388608     # max static file served
max_exec_output_size=1048576     # max output streamed by an executable/.so
```

Example with stricter limits:

```ini
max_php_response_size=262144
max_static_file_size=1048576
max_exec_output_size=524288
```

When a limit is exceeded:

| Category | Setting | Result |
|---|---|---|
| PHP | `max_php_response_size` | HTTP `503` + `503: response exceeds configured size limit.` |
| Static file | `max_static_file_size` | body is truncated at the limit |
| Executable / `.so` | `max_exec_output_size` | output is truncated and the program is stopped |

Notes:

- `0` disables the limit for that category.
- PHP output also has a hard buffer cap of **2 MiB**, regardless of
  `max_php_response_size`.
- Unknown keys are ignored; lines starting with `#` are comments.

## Run a Rust program in the browser

Executable:

```bash
rustc hello.rs -o /var/www/html/hello
chmod +x /var/www/html/hello
# http://127.0.0.1:8080/hello
```

Shared library:

```bash
rustc --crate-type=cdylib hello.rs -o /var/www/html/hello.so
chmod +x /var/www/html/hello.so
# http://127.0.0.1:8080/hello.so
```

The program's stdout and stderr become the response body, subject to
`max_exec_output_size`.

## PHP-FPM

The server tries these sockets in order and uses the first reachable one:

1. `/run/php/php-fpm.sock`
2. `/run/php/php8.4-fpm.sock`
3. `/tmp/php-fpm.sock`

Recommended (root + systemd):

```bash
sudo systemctl start php8.4-fpm
```

Without systemd (for example WSL), run FPM as your user on the fallback socket.
Create `/tmp/php-fpm.conf`:

```ini
[global]
pid = /tmp/php-fpm.pid
error_log = /tmp/php-fpm-error.log
daemonize = no
[www]
listen = /tmp/php-fpm.sock
listen.mode = 0666
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

and start it:

```bash
/usr/sbin/php-fpm8.4 -y /tmp/php-fpm.conf -F
```

If FPM is unreachable, a directory request (for example `/`) falls back to
`index.html`, while a direct `.php` request returns an error response.

## Notes

- Single-threaded: handles one connection at a time.
- The port (`8080`) is set in the `address` structure in `httpserver.asm`.
