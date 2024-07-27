package udpserver

import "core:net"
import "core:fmt"
import "core:bytes"

main :: proc() {
	endp, _, err := net.resolve("127.0.0.1:6969")

	if err != nil {
		fmt.panicf("Resolve error %s", err)
	}

	conn, conn_err := net.make_bound_udp_socket(endp.address, endp.port)

	if conn_err != nil {
		fmt.panicf("connection error %s, conn_err")
	}

	for {

		data: [256]u8

		_, clendp, recv_err := net.recv_udp(conn, data[:])

		if recv_err != nil {
			fmt.panicf("udp recv error: %s")
		}

		res := string(data[:])
		fmt.println("client said: ", res)

		st := "Hello, Client Back"

		_, send_err := net.send_udp(conn, transmute([]u8)st, clendp)

		if send_err != nil {
			fmt.panicf("connection error %s", send_err)
		}

	}
}