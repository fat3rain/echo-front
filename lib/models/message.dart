class Message {
  final String type;
  final String? to;
  final String? from;
  final dynamic payload;

  Message({required this.type, this.to, this.from, this.payload});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      type: json['type'],
      to: json['to'],
      from: json['from'],
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'to': to, 'payload': payload};
  }
}
