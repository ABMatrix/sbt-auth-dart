/// Rpc request type
class RequestArgument {
  /// Constructor
  RequestArgument({
    required this.method,
    required this.params,
  });

  /// Method name
  String method;

  /// Request params
  List<dynamic> params;
}
