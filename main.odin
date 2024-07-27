package main

import rl "vendor:raylib"
import "core:fmt"
import "core:net"
import "core:os"
import "core:mem"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
PADDLE_WIDTH :: 10
PADDLE_HEIGHT :: 100
BALL_RADIUS :: 10

Paddle :: struct {
	x, y: i32,
	speed: f32,
}

Ball :: struct {
	x, y: i32,
	dx, dy: f32,
}

GameState :: struct {
	leftPaddle, rightPaddle: Paddle,
	ball: Ball,
	leftScore, rightScore: i32,
}

initGame :: proc() -> GameState {
	return GameState {
		Paddle {
			10.0,
			(SCREEN_HEIGHT / 2.0) - (PADDLE_HEIGHT / 2.0),
			500.0,
		},
		Paddle {
			(SCREEN_WIDTH - 20), 
			(SCREEN_HEIGHT / 2.0) - (PADDLE_HEIGHT / 2.0),
			500.0,
		},
		Ball {
			(SCREEN_WIDTH / 2.0),
			SCREEN_HEIGHT / 2.0,
			200.0, 
			200.0,
		},
		0, 
		0,
	}
}

PacketType :: enum {
	PADDLE_UPDATE,
	GAME_STATE,
}

PaddleUpdate :: struct {
	y: i32
}

NetworkGameState :: struct {
	left_paddle_y: i32,
	ball_x, ball_y: i32,
	left_score, right_score: i32
}

Packet :: struct {
	type: PacketType,
	data: union {
		PaddleUpdate,
		NetworkGameState,
	}
}

updateGameClient :: proc(g: ^GameState, deltaTime: f32, soc: net.UDP_Socket, endp: net.Endpoint) {
	if rl.IsKeyDown(rl.KeyboardKey.UP) { 
		g.rightPaddle.y -= cast(i32)(g.rightPaddle.speed * deltaTime)

		packet1: Packet = {
			PacketType.PADDLE_UPDATE, 
			PaddleUpdate {g.rightPaddle.y},
		}
		
		ok, up_send_err_u := net.send_udp(soc, mem.ptr_to_bytes(&packet1), endp)

		if up_send_err_u != nil {
			fmt.panicf("networking error %s", up_send_err_u)
		}
	}
	if rl.IsKeyDown(rl.KeyboardKey.DOWN) {  
		g.rightPaddle.y += cast(i32)( g.rightPaddle.speed * deltaTime)

		packet2: Packet =  {PacketType.PADDLE_UPDATE, PaddleUpdate {g.rightPaddle.y}}

		_, up_send_err_d := net.send_udp(soc, mem.ptr_to_bytes(&packet2), endp)
		
		if up_send_err_d != nil {
			fmt.panicf("networking error %s", up_send_err_d)
		}
	}

	data: [size_of(Packet)]u8

	bytes_read, _, recv_err := net.recv_udp(soc, data[:])

	fmt.println(bytes_read)

//	if recv_err != nil && recv_err != net.Accept_Error.Would_Block  {
//		fmt.panicf("networking error %s", recv_err)
//	}

	if bytes_read != 0 {
		pac := mem.slice_data_cast([]Packet, data[:bytes_read])[0]	
		if pac.type == PacketType.GAME_STATE {
			g.leftPaddle.y	= pac.data.(NetworkGameState).left_paddle_y
			g.ball.x = pac.data.(NetworkGameState).ball_x
			g.ball.y = pac.data.(NetworkGameState).ball_y
			g.leftScore = pac.data.(NetworkGameState).left_score
			g.rightScore = pac.data.(NetworkGameState).right_score
		}
	}
}

updateGameServer :: proc(g: ^GameState, deltaTime: f32, soc: net.UDP_Socket, endp: net.Endpoint, clendp: net.Endpoint) {
	if rl.IsKeyDown(rl.KeyboardKey.W) {
		g.leftPaddle.y -=  cast(i32)(g.leftPaddle.speed * deltaTime)
	}
	if rl.IsKeyDown(rl.KeyboardKey.S) {  
		g.leftPaddle.y +=  cast(i32)(g.leftPaddle.speed * deltaTime)
	}

	g.leftPaddle.y = cast(i32)rl.Clamp( cast(f32) g.leftPaddle.y, 0, SCREEN_HEIGHT - PADDLE_HEIGHT)

	data: [size_of(Packet)]u8
	bytes_read, _, recv_err := net.recv_udp(soc, data[:])

//	if recv_err != nil && recv_err != net.Accept_Error.Would_Block  {
//		fmt.panicf("networking error %s", recv_err)
//	}

	if bytes_read != 0 {
		pac := mem.slice_data_cast([]Packet, data[:bytes_read])[0]
		if pac.type == PacketType.PADDLE_UPDATE {
			g.rightPaddle.y = pac.data.(PaddleUpdate).y
		}
	}

	g.rightPaddle.y = cast(i32)rl.Clamp( cast(f32) g.rightPaddle.y, 0, SCREEN_HEIGHT - PADDLE_HEIGHT)

	g.ball.x += cast(i32)(g.ball.dx * deltaTime)
	g.ball.y += cast(i32)(g.ball.dy * deltaTime)


	if g.ball.y <= 0 || g.ball.y >= SCREEN_HEIGHT {
		g.ball.dy = -g.ball.dy
	}
	  
	if g.ball.x <= g.leftPaddle.x + PADDLE_WIDTH && g.ball.y + BALL_RADIUS >= g.leftPaddle.y && g.ball.y <= g.leftPaddle.y + PADDLE_HEIGHT {
		g.ball.dx = -g.ball.dx
	}

	if g.ball.x + BALL_RADIUS >= g.rightPaddle.x && g.ball.y + BALL_RADIUS >= g.rightPaddle.y && g.ball.y <= g.rightPaddle.y + PADDLE_HEIGHT {
		g.ball.dx = -g.ball.dx
	}

	if g.ball.x < 0  {
		g.leftScore += 1
		g.ball.x = (SCREEN_WIDTH / 2.0)
		g.ball.y = SCREEN_HEIGHT / 2.0
		g.ball.dx = 200
		g.ball.dy = 200
	}
	else if g.ball.x > SCREEN_WIDTH {
		g.rightScore += 1
		g.ball.x = (SCREEN_WIDTH / 2.0)
		g.ball.y = SCREEN_HEIGHT / 2.0
		g.ball.dx = 200
		g.ball.dy = 200
	}

	packet: Packet = {
		PacketType.GAME_STATE,
		NetworkGameState {
			g.leftPaddle.y,
			g.ball.x,
			g.ball.y,
			g.leftScore,
			g.rightScore,
		}

	}

	ok, send_err :=  net.send_udp(soc, mem.ptr_to_bytes(&packet), clendp)
	if send_err != nil {
		fmt.panicf("networking error %s", send_err)
	}

}

serverGame :: proc() {

	endp,_, err := net.resolve("127.0.0.1:6969")

	if err != nil {
		fmt.panicf("Resolve error %s", err)
	}

	conn, conn_err := net.make_bound_udp_socket(endp.address, endp.port)
	
	if conn_err != nil {
		fmt.panicf("connection error %s", conn_err)
	}

	data: [256]u8
	_, clendp, recv_err := net.recv_udp(conn, data[:])


	if recv_err != nil {
			fmt.panicf("udp recv error: %s")
	}

	res := string(data[:])
	//fmt.println("client said: ", res)

	net.set_blocking(conn, false);

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "pong-server")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	g := initGame()
	
	for !rl.WindowShouldClose() {
		fmt.println("in client game loop")
		
		
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		
		// Draw Middle Line
		for y := 0; y < SCREEN_HEIGHT; y += 20 {
			rl.DrawRectangle(SCREEN_WIDTH / 2 - 10 / 2, cast(i32)y, 10, 10, rl.RAYWHITE)
		}
	
		rl.DrawRectangle(g.leftPaddle.x, g.leftPaddle.y, PADDLE_WIDTH, PADDLE_HEIGHT, rl.RAYWHITE)
		rl.DrawRectangle(g.rightPaddle.x, g.rightPaddle.y, PADDLE_WIDTH, PADDLE_HEIGHT, rl.RAYWHITE)
		rl.DrawRectangle(g.ball.x, g.ball.y, BALL_RADIUS, BALL_RADIUS, rl.RAYWHITE)

		rl.DrawText(fmt.ctprint(g.leftScore), SCREEN_WIDTH / 4, 20, 40, rl.RAYWHITE)
		rl.DrawText(fmt.ctprint(g.rightScore), 3 * SCREEN_WIDTH / 4, 20, 40, rl.RAYWHITE)

		rl.EndDrawing()

		updateGameServer(&g, rl.GetFrameTime(), conn, endp, clendp)	
	}
}

clientGame :: proc() {
	fmt.println("Welcome to pong console - we do not support console commands at this time")

	endp, _, err := net.resolve("127.0.0.1:6969")

	if err != nil {
		fmt.panicf("Resolve error %s", err)
	}

	conn, conn_err := net.make_unbound_udp_socket(net.Address_Family.IP4)
	
	if conn_err != nil {
		fmt.panicf("connection error %s", conn_err)
	}

	st := "Hello, Server"

	_, err2 := net.send_udp(conn, transmute([]u8)st, endp)

	if err2 != nil {
		fmt.panicf("connection error %s", err2)
	}

	net.set_blocking(conn, false);

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "pong-client")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	g := initGame()
	
	for !rl.WindowShouldClose() {
		fmt.println("in client game loop")
		
		
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		
		// Draw Middle Line
		for y := 0; y < SCREEN_HEIGHT; y += 20 {
			rl.DrawRectangle(SCREEN_WIDTH / 2 - 10 / 2, cast(i32)y, 10, 10, rl.RAYWHITE)
		}

		rl.DrawRectangle(g.leftPaddle.x, g.leftPaddle.y, PADDLE_WIDTH, PADDLE_HEIGHT, rl.RAYWHITE)
		rl.DrawRectangle(g.rightPaddle.x, g.rightPaddle.y, PADDLE_WIDTH, PADDLE_HEIGHT, rl.RAYWHITE)
		rl.DrawRectangle(g.ball.x, g.ball.y, BALL_RADIUS, BALL_RADIUS, rl.RAYWHITE)

		rl.DrawText(fmt.ctprint(g.leftScore), SCREEN_WIDTH / 4, 20, 40, rl.RAYWHITE)
		rl.DrawText(fmt.ctprint(g.rightScore), 3 * SCREEN_WIDTH / 4, 20, 40, rl.RAYWHITE)

		rl.EndDrawing()

		updateGameClient(&g, rl.GetFrameTime(), conn, endp)
	}
}

startGame :: proc() {
	if len(os.args) < 2 {
		return 
	}

	if os.args[1] == "server" {
		serverGame()
	} 
	else {
		clientGame()
	}
}

main :: proc() {
	startGame()
}
