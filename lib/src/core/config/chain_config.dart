/// Centralized configuration for blockchain chain properties.
///
/// This class encapsulates all chain-specific settings including network ID,
/// API endpoints, authentication keys, and token addresses. This ensures
/// consistency across payment generation and monitoring.
class ChainConfig {
  /// The chain ID used for the Etherscan API (e.g., 56 for BSC, 1 for Ethereum).
  final int chainId;

  /// The base URL for Etherscan API (e.g., https://api.etherscan.io).
  final String apiBaseUrl;

  /// The API key for authentication with Etherscan.
  final String apiKey;

  /// The ERC-20 token contract address on this chain.
  final String tokenAddress;

  /// Display name for the chain (e.g., "BSC", "Ethereum").
  final String chainName;

  ChainConfig({
    required this.chainId,
    required this.apiBaseUrl,
    required this.apiKey,
    required this.tokenAddress,
    required this.chainName,
  });

  /// Factory constructor for Binance Smart Chain (BSC) configuration.
  factory ChainConfig.bsc({
    required String apiKey,
    required String tokenAddress,
  }) {
    return ChainConfig(
      chainId: 56,
      apiBaseUrl: 'https://api.etherscan.io',
      apiKey: apiKey,
      tokenAddress: tokenAddress,
      chainName: 'BSC',
    );
  }

  /// Factory constructor for Ethereum mainnet configuration.
  factory ChainConfig.ethereum({
    required String apiKey,
    required String tokenAddress,
  }) {
    return ChainConfig(
      chainId: 1,
      apiBaseUrl: 'https://api.etherscan.io',
      apiKey: apiKey,
      tokenAddress: tokenAddress,
      chainName: 'Ethereum',
    );
  }

  @override
  String toString() =>
      'ChainConfig(chainId: $chainId, chain: $chainName, token: $tokenAddress)';
}
