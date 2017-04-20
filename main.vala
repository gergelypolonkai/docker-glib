namespace Docker {
    public class Container: Object {}

    public class Connection: Object {
        public string socket {
            get;
            set;
            default = "/var/run/docker.sock";
        }

        private GLib.UnixSocketAddress address;
        private GLib.SocketClient client;
        private GLib.SocketConnection conn;

        private int status = 0;
        private string? status_message = null;
        private int content_length = 0;
        private bool headers_received = false;
        private string? contents = null;

        public Connection(string socket = "/var/run/docker.sock") {
            Object(socket: socket);

            address =  new GLib.UnixSocketAddress(socket);
            client = new SocketClient();
            conn = client.connect(address);
        }

        public async List<Container>
        list_containers() {
            var message = "GET /containers/json HTTP/1.1\r\nHost: v1.27\r\n\r\n";
            yield conn.output_stream.write_async(message.data,
                                                 Priority.DEFAULT);

            var input = new DataInputStream(conn.input_stream);
            input.set_newline_type(GLib.DataStreamNewlineType.CR_LF);

            while (!headers_received) {
                message = input.read_line(null).strip();

                if ((status == 0) && (message.has_prefix("HTTP/1.1 "))) {
                    status = message.slice(9, 12).to_int();
                    status_message =  message.slice(13, message.length);
                    // Reset some variables
                    headers_received = false;
                    content_length = 0;
                    contents = null;

                    // TODO: Handle error codes
                } else if (message.down().has_prefix("content-length: ")) {
                    content_length = message.slice(16, message.length).to_int();
                } else if (message.length == 0) {
                    headers_received = true;
                    contents = "";
                } else {
                    // TODO: Handle other headers
                }
            }

            stdout.printf("Got headers\n");
            yield;

            input.set_newline_type(GLib.DataStreamNewlineType.LF);

            while (content_length > 0) {
                size_t read_len;
                var line = input.read_line_utf8(out read_len);
                // read_len doesn’t contain the newline at the end of the line
                read_len++;
                contents += line;

                if (read_len == content_length) {
                    break;
                } else {
                    content_length -= (int)read_len;
                }
            }
            stdout.printf("Got contents\n");
            yield;

            var parser = new Json.Parser();
            parser.load_from_data(contents, -1);
            stdout.printf("Parsing done\n");
            yield;

            var root_array = parser.get_root().get_array();
            var result = new List<Container>();

            foreach (var data in root_array.get_elements()) {
                var container = new Container();
                result.prepend(container);

                stdout.printf("A container!\n");
            }

            stdout.printf("Yielding…\n");
            yield;
            stdout.printf("Returning…\n");
            return result;
        }
    }
}

public static int
main(string[] args) {
    var loop = new MainLoop();
    var docker =  new Docker.Connection();

    docker.list_containers.begin((obj, res) => {
            stdout.printf("Done!\n");
            var containers = docker.list_containers.end(res);

            stdout.printf("Done!\n");
        });

    loop.run();

    return 0;
}
