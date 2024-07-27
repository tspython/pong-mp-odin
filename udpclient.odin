package udpclient

import "core:net"
import "core:fmt"

main :: proc() {
	endp, _, err := net.resolve("127.0.0.1:6969")

	if err != nil {
		fmt.panicf("Resolve error %s", err)
	}

	conn, conn_err := net.make_unbound_udp_socket(net.Address_Family.IP4)

	if conn_err != nil {
		fmt.panicf("connection error %s", conn_err)
	}
	for {
		st := "Hello, Server"

		_, err2 := net.send_udp(conn, transmute([]u8)st, endp)

		if err2 != nil {
			fmt.panicf("connection error %s", err2)
		}

		data: [256]u8


		_, _, recv_err := net.recv_udp(conn, data[:])

		if recv_err != nil {
			fmt.panicf("udp recv error: %s")
		}

		res := string(data[:])
		fmt.println("server said: ", res) 
	}
	// net.close(conn)
}