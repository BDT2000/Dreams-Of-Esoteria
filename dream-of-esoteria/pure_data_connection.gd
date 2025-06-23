extends Node

var tcp_client: StreamPeerTCP
var connection_timer: Timer
var send_timer: Timer
var max_connection_time: float = 10.0
var max_send_time: float = 5.0
var connection_start_time: float
var pending_data: PackedByteArray
var bytes_to_send: int = 0
var bytes_sent_total: int = 0

func _ready():
	tcp_client = StreamPeerTCP.new()
	
	# Create and configure timer for connection timeout
	connection_timer = Timer.new()
	connection_timer.wait_time = max_connection_time
	connection_timer.one_shot = true
	connection_timer.timeout.connect(_on_connection_timeout)
	add_child(connection_timer)
	
	# Create timer for send timeout
	send_timer = Timer.new()
	send_timer.wait_time = max_send_time
	send_timer.one_shot = true
	send_timer.timeout.connect(_on_send_timeout)
	add_child(send_timer)
	
	connect_to_server()

func connect_to_server():
	print("Attempting to connect to 127.0.0.1:4242...")
	
	var result = tcp_client.connect_to_host("127.0.0.1", 4242)
	
	if result != OK:
		print("Failed to initiate connection. Error code: ", result)
		return
	
	# Start connection timeout timer
	connection_timer.start()
	connection_start_time = Time.get_unix_time_from_system()
	
	# Start polling the connection status
	poll_connection()

func poll_connection():
	# Poll the TCP client to update its status
	tcp_client.poll()
	
	var status = tcp_client.get_status()
	
	match status:
		StreamPeerTCP.STATUS_CONNECTED:
			connection_timer.stop()
			print("Connected successfully!")
			send_message("hello world")
			return
		
		StreamPeerTCP.STATUS_CONNECTING:
			# Still connecting, check again next frame
			await get_tree().process_frame
			poll_connection()
		
		StreamPeerTCP.STATUS_ERROR:
			connection_timer.stop()
			print("Connection failed with error")
			return
		
		StreamPeerTCP.STATUS_NONE:
			connection_timer.stop()
			print("Connection closed or failed")
			return

func _on_connection_timeout():
	print("Connection timed out after ", max_connection_time, " seconds")
	tcp_client.disconnect_from_host()

func send_message(message: String):
	if tcp_client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		print("Not connected to server")
		return
	
	print("Sending message: '", message, "'")
	pending_data = message.to_utf8_buffer()
	bytes_to_send = pending_data.size()
	bytes_sent_total = 0
	
	# Start send timeout timer
	send_timer.start()
	
	# Begin sending process
	send_data_chunk()

func send_data_chunk():
	if tcp_client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		print("Connection lost during send")
		send_timer.stop()
		return
	
	# Poll to update connection status
	tcp_client.poll()
	
	if bytes_sent_total < bytes_to_send:
		# Calculate remaining data to send
		var remaining_data = pending_data.slice(bytes_sent_total)
		
		# Try to send remaining data
		var result = tcp_client.put_data(remaining_data)
		
		if result == OK:
			# In Godot 4, put_data() only returns Error, not bytes sent
			# We assume all remaining data was sent if result is OK
			bytes_sent_total = bytes_to_send
			
			print("Data sent successfully (", bytes_to_send, " bytes)")
			
			# All data sent successfully
			send_timer.stop()
			print("Message sent successfully! Closing connection...")
			tcp_client.disconnect_from_host()
			print("Connection closed")
		else:
			# Error sending data
			send_timer.stop()
			print("Error sending data: ", result)
			tcp_client.disconnect_from_host()
			print("Connection closed due to send error")
	# This else block is no longer needed since we handle completion above

func _on_send_timeout():
	print("Send operation timed out after ", max_send_time, " seconds")
	tcp_client.disconnect_from_host()
	print("Connection closed due to send timeout")

func _exit_tree():
	if send_timer:
		send_timer.stop()
	if connection_timer:
		connection_timer.stop()
	if tcp_client:
		tcp_client.disconnect_from_host()
