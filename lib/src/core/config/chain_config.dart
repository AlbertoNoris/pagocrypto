/// Centralized configuration for blockchain chain properties.
///
/// This class encapsulates all chain-specific settings including network ID,
/// proxy endpoints, and token addresses. The API key is kept secure on the
/// proxy server side.
class ChainConfig {
  /// The chain ID used for the Etherscan API (e.g., 56 for BSC, 1 for Ethereum).
  final int chainId;

  /// The proxy endpoint URL that handles BscScan/Etherscan API calls server-side.
  /// This keeps the API key secure and not exposed in the client app.
  final String proxyUrl;

  /// The block explorer base URL (e.g., https://bscscan.com, https://etherscan.io).
  final String explorerUrl;

  /// The ERC-20 token contract address on this chain.
  final String tokenAddress;

  /// Display name for the chain (e.g., "BSC", "Ethereum").
  final String chainName;

  ChainConfig({
    required this.chainId,
    required this.proxyUrl,
    required this.explorerUrl,
    required this.tokenAddress,
    required this.chainName,
  });

  /// Factory constructor for Binance Smart Chain (BSC) configuration.
  factory ChainConfig.bsc({
    required String proxyUrl,
    required String tokenAddress,
  }) {
    return ChainConfig(
      chainId: 56,
      proxyUrl: proxyUrl,
      explorerUrl: 'https://bscscan.com',
      tokenAddress: tokenAddress,
      chainName: 'BSC',
    );
  }

  /// Factory constructor for Ethereum mainnet configuration.
  factory ChainConfig.ethereum({
    required String proxyUrl,
    required String tokenAddress,
  }) {
    return ChainConfig(
      chainId: 1,
      proxyUrl: proxyUrl,
      explorerUrl: 'https://etherscan.io',
      tokenAddress: tokenAddress,
      chainName: 'Ethereum',
    );
  }

  @override
  String toString() =>
      'ChainConfig(chainId: $chainId, chain: $chainName, token: $tokenAddress)';
}
