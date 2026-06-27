extends Control

const NGROK_API = "http://localhost:4040/api/tunnels"
const NGROK_POLL_INTERVAL = 1.0
const NGROK_MAX_RETRIES = 20

@onready var _host_btn: Button = $Panel/VBox/HostBtn
@onready var _join_btn: Button = $Panel/VBox/JoinBtn
@onready var _ip_input: LineEdit = $Panel/VBox/IPRow/IPInput
@onready var _status: Label = $Panel/VBox/Status
@onready var _url_row: HBoxContainer = $Panel/VBox/URLRow
@onready var _url_label: LineEdit = $Panel/VBox/URLRow/URLLabel
@onready var _copy_btn: Button = $Panel/VBox/URLRow/CopyBtn

var _http: HTTPRequest
var _http_pending: bool = false
var _ngrok_retries: int = 0
var _poll_timer: Timer

func _ready() -> void:
	_host_btn.pressed.connect(_on_host)
	_join_btn.pressed.connect(_on_join)
	_copy_btn.pressed.connect(_on_copy)
	$Panel/VBox/BackBtn.pressed.connect(_on_back)
	Network.player_connected.connect(_on_player_connected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.server_disconnected.connect(_on_server_disconnected)

	_url_row.hide()

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_ngrok_response)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = NGROK_POLL_INTERVAL
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_fetch_ngrok_url)
	add_child(_poll_timer)

	# モードに応じて初期UIを設定
	if Network.game_mode == "local":
		$Panel/VBox/Title.text = "ローカル対戦"
		$Panel/VBox/IPRow/IPInput.text = "ws://127.0.0.1:7777"
		$Panel/VBox/IPRow/IPInput.placeholder_text = "ws://127.0.0.1:7777"

func _on_host() -> void:
	if not Network.host():
		_status.text = "サーバー起動失敗"
		return

	_host_btn.disabled = true
	_join_btn.disabled = true
	_ngrok_retries = 0

	if Network.game_mode == "local":
		_show_ngrok_url("ws://127.0.0.1:7777")
		_status.text = "ローカルサーバー起動中\n同じPCまたはLAN内から接続可能"
		return

	# ① 既存のngrokトンネルが生きているか確認
	_status.text = "既存のngrokトンネルを確認中..."
	if _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http.request(NGROK_API)
	await get_tree().create_timer(1.2).timeout

	if _url_row.visible:
		return

	# ② 使えなかった → 全プロセス終了して新規起動
	_status.text = "ngrokをリセット中..."
	await Network.start_ngrok()
	await get_tree().create_timer(5.0).timeout
	_status.text = "ngrok URL取得中..."
	_poll_timer.start()

func _fetch_ngrok_url() -> void:
	if _http_pending:
		return
	if _ngrok_retries >= NGROK_MAX_RETRIES:
		_poll_timer.stop()
		_status.text = "ngrok URLの取得に失敗しました\n手動でURLを確認してください（localhost:4040）"
		return
	_ngrok_retries += 1
	_http_pending = true
	_http.request(NGROK_API)

func _on_ngrok_response(result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_pending = false
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return
	var data = json.get_data()
	if not data is Dictionary or not data.has("tunnels"):
		return
	for tunnel in data["tunnels"]:
		if tunnel.has("public_url"):
			var url: String = tunnel["public_url"]
			# https:// → wss:// に変換して表示
			var ws_url = "wss://" + url.trim_prefix("https://")
			_poll_timer.stop()
			_show_ngrok_url(ws_url)
			return

func _show_ngrok_url(url: String) -> void:
	_url_label.text = url
	_url_row.show()
	_ip_input.text = url
	_status.text = "このURLを相手に送ってください ↑\n相手の接続を待っています..."

func _on_copy() -> void:
	DisplayServer.clipboard_set(_url_label.text)
	_copy_btn.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	_copy_btn.text = "コピー"

func _on_join() -> void:
	var url = _ip_input.text.strip_edges()
	if url.is_empty():
		_status.text = "URLを入力してください"
		return
	if Network.join(url):
		_status.text = "接続中..."
		_host_btn.disabled = true
		_join_btn.disabled = true
	else:
		_status.text = "接続失敗"

func _on_player_connected(_id: int) -> void:
	if Network.players.size() >= 2:
		await get_tree().create_timer(0.3).timeout
		get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_connection_failed() -> void:
	_status.text = "接続に失敗しました"
	_host_btn.disabled = false
	_join_btn.disabled = false

func _on_server_disconnected() -> void:
	_status.text = "サーバーが切断されました"
	_host_btn.disabled = false
	_join_btn.disabled = false

func _on_back() -> void:
	_poll_timer.stop()
	Network.stop_ngrok()
	multiplayer.multiplayer_peer = null
	Network.players.clear()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
