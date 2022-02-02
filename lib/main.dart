import 'dart:convert';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  late MediaStream _localStream;
  final sdpController = TextEditingController();
  bool _offer = false;
  late RTCPeerConnection _peerConnection;

  @override
  void dispose() {
    _localStream.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderers();
    _createPeerConnection().then((pc){
      _peerConnection = pc;
    });
    super.initState();
  }

  _createPeerConnection() async{
    Map<String,dynamic> configuration = {
      "iceServers":[
        {"url":"stun:stun.l.google.com:19302"}
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory":{
        "offerToReceiveAudio": true,
        "offerToReceiveVideo": true,
      },
      "optional":[]
    };
    _localStream = await _getUserMedia();
    RTCPeerConnection pc = await createPeerConnection(configuration, offerSdpConstraints);
    pc.addStream(_localStream);

    pc.onIceCandidate = (e){
      if(e.candidate != null){
        print(json.encode({
          'candidate':e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
      }
    };

    pc.onIceConnectionState = (e){
      print(e);
    };

    pc.onAddStream = (stream){
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  initRenderers() async{
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth':
          '1280', // Provide your own width, height and frame rate here
          'minHeight': '720',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      },
    };

    MediaStream stream = await navigator.getUserMedia(mediaConstraints);

    _localRenderer.srcObject = stream;
    return stream;
  }

  void _createOffer() async {
    RTCSessionDescription description =
    await _peerConnection.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    _offer = true;

    _peerConnection.setLocalDescription(description);
  }

  void _setRemoteDescription() async{
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    String sdp = write(session, null);
    RTCSessionDescription description = RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
    await _peerConnection.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());
    print(json.encode(session));
    // print(json.encode({
    //       'sdp': description.sdp.toString(),
    //       'type': description.type.toString(),
    //     }));

    _peerConnection.setLocalDescription(description);
  }

  void _setCandidate() async{
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate =
    RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }

  SizedBox videoRenderers() => SizedBox(
    height: 210,
    child: Row(
      children: [
        Flexible(
          child: Container(
            key: const Key('local'),
            margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
            decoration: const BoxDecoration(color: Colors.black),
            child: RTCVideoView(_localRenderer),
          ),
        ),
        Flexible(
          child: Container(
            key: const Key('remote'),
            margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
            decoration: const BoxDecoration(color: Colors.black),
            child: RTCVideoView(_remoteRenderer),
          ),
        )
      ],
    ),
  );

  Row offerAnswerButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children:  [
      ElevatedButton(
        onPressed: _createOffer,
        child: const Text('Offer'),
      ),
      ElevatedButton(
        onPressed: _createAnswer,
        child: Text('Answer'),
      ),
    ],
  );

  Padding sdpCandidateTF() => Padding(
    padding: const EdgeInsets.all(16.0),
    child: TextField(
      controller: sdpController,
      keyboardType: TextInputType.multiline,
      maxLines: 4,
      maxLength: TextField.noMaxLength,
    ),
  );

  Row sdpCandidateButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      ElevatedButton(
          onPressed: _setRemoteDescription,
          child: Text('Set Remote description')
      ),

      ElevatedButton(
          onPressed: _setCandidate,
          child: Text('Set Candidate')
      )
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          videoRenderers(),
          offerAnswerButtons(),
          sdpCandidateTF(),
          sdpCandidateButtons(),
        ],
      ),
    );
  }
}
