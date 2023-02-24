import 'package:flutter/material.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

import 'grant_authorization.dart';

class SolanaSignPage extends StatefulWidget {
  final SbtAuth sbtauth;

  const SolanaSignPage({required this.sbtauth, super.key});

  @override
  State<SolanaSignPage> createState() => _SolanaSignPageState();
}

class _SolanaSignPageState extends State<SolanaSignPage> {
  String hash = '';
  String createAccountHash = '';
  String tokenHash = '';
  String solanaAddress = '';

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    initSolana();
    super.initState();
  }

  initSolana() async {
    try {
      await widget.sbtauth.init(chain: SbtChain.SOLANA);
    } catch (e) {
      debugPrint(e.toString());
    }
    if (widget.sbtauth.solanaSinger == null) {
      goToAuthorization();
    }
    setState(() {
      solanaAddress = widget.sbtauth.user!.publicKeyAddress['SOLANA'] == null
          ? widget.sbtauth.solanaCore!
              .getAddress(isTestnet: widget.sbtauth.developMode)
          : widget.sbtauth.user!.publicKeyAddress['SOLANA']['address'];
    });
    debugPrint(solanaAddress);
  }

  goToAuthorization() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GrantAuthorizationPage(
                  auth: widget.sbtauth,
                  chain: SbtChain.SOLANA,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana Sign'),
      ),
      body: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
              onPressed: () {
                widget.sbtauth
                    .backupWithOneDrive('123', chain: SbtChain.SOLANA);
              },
              child: const Text('Backup by one drive')),
          const SizedBox(height: 40),
          TextButton(
              onPressed: () {
                widget.sbtauth.recoverByOneDrive('123', chain: SbtChain.SOLANA);
              },
              child: const Text('Recover by one drive')),
          const SizedBox(height: 40),
          TextField(
            controller: _emailController,
          ),
          TextButton(
              onPressed: () {
                widget.sbtauth.sendBackupPrivateKey(
                  '123',
                  _emailController.text.trim(),
                  'code',
                  chain: SbtChain.SOLANA,
                );
              },
              child: const Text('send')),
          const SizedBox(height: 20),
          Text(solanaAddress),
          TextButton(
            onPressed: _sendSol,
            child: const Text('Send sol'),
          ),
          const SizedBox(height: 10),
          Text(hash),
          TextButton(
            onPressed: _createAccount,
            child: const Text('Create associated account'),
          ),
          const SizedBox(height: 10),
          Text(createAccountHash),
          TextButton(
            onPressed: _sendSolToken,
            child: const Text('Send sol token'),
          ),
          const SizedBox(height: 10),
          Text(tokenHash),
          const SizedBox(height: 10),
        ],
      )),
    );
  }

  _sendSol() async {
    final singer = widget.sbtauth.solanaSinger;
    final fromAddress = Ed25519HDPublicKey.fromBase58(solanaAddress);
    final toAddress = Ed25519HDPublicKey.fromBase58(solanaAddress);
    final instruction = SystemInstruction.transfer(
      fundingAccount: fromAddress,
      recipientAccount: toAddress,
      lamports: 100000,
    );
    final res = await singer!.sendTransaction(instruction, fromAddress);
    setState(() {
      hash = res;
    });
  }

  _createAccount() async {
    final singer = widget.sbtauth.solanaSinger;
    final fromAddress = Ed25519HDPublicKey.fromBase58(solanaAddress);
    final toAddress = Ed25519HDPublicKey.fromBase58(
        'EFA5zmDsatecVH6b1W2EtMKCGGAWo2r8izFn46j6BQnZ');
    final tokenAddress = Ed25519HDPublicKey.fromBase58(
        '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU');

    final res = await singer!
        .createAssociatedTokenAccount(fromAddress, toAddress, tokenAddress);
    setState(() {
      createAccountHash = res;
    });
  }

  _sendSolToken() async {
    Future<ProgramAccount?> getAssociatedTokenAccount({
      required Ed25519HDPublicKey owner,
      required Ed25519HDPublicKey mint,
      Commitment commitment = Commitment.finalized,
    }) async {
      final rpcClient = RpcClient('https://test-rpc-solana.abmatrix.cn',
          timeout: const Duration(seconds: 30));
      final accounts = await rpcClient.getTokenAccountsByOwner(
        owner.toBase58(),
        TokenAccountsFilter.byMint(mint.toBase58()),
        encoding: Encoding.jsonParsed,
        commitment: commitment,
      );
      if (accounts.isEmpty) return null;

      return accounts.first;
    }

    final singer = widget.sbtauth.solanaSinger;
    final fromAddress = Ed25519HDPublicKey.fromBase58(solanaAddress);
    final toAddress = Ed25519HDPublicKey.fromBase58(
        'EFA5zmDsatecVH6b1W2EtMKCGGAWo2r8izFn46j6BQnZ');
    final tokenAddress = Ed25519HDPublicKey.fromBase58(
        '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU');
    final associatedRecipientAccount = await getAssociatedTokenAccount(
      owner: toAddress,
      mint: tokenAddress,
      commitment: Commitment.confirmed,
    );
    final associatedSenderAccount = await getAssociatedTokenAccount(
      owner: fromAddress,
      mint: tokenAddress,
      commitment: Commitment.confirmed,
    );
    if (associatedSenderAccount == null) {
      throw SbtAuthException('associatedSenderAccount == null');
    }
    if (associatedRecipientAccount == null) {
      throw SbtAuthException('associatedRecipientAccount == null');
    }
    final instruction = TokenInstruction.transfer(
      source: Ed25519HDPublicKey.fromBase58(associatedSenderAccount.pubkey),
      destination:
          Ed25519HDPublicKey.fromBase58(associatedRecipientAccount.pubkey),
      owner: fromAddress,
      amount: 1,
    );
    final res = await singer!.sendTransaction(instruction, fromAddress);
    setState(() {
      tokenHash = res;
    });
  }
}
