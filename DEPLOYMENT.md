# Deployment Guide

This guide covers deploying the Etherscan proxy API to Vercel.

## Prerequisites

- Vercel account (free tier works fine)
- Etherscan API key (get one at https://etherscan.io/myapikey)

## Vercel Environment Variables

You need to set the following environment variables in your Vercel project:

### Required
- `ETHERSCAN_API_KEY`: Your Etherscan API key (supports BSC, Ethereum, and other chains)

### Optional (for Telegram error alerts)
- `TELEGRAM_BOT_TOKEN`: Your Telegram bot token
- `TELEGRAM_CHAT_ID`: Your Telegram chat ID
- `APP_PROJECT`: Project name for alerts (default: "Pagocrypto")

### Required for QR Code Generation
- `QRIO_API_KEY`: Your qr.io API key (already configured)

## Setup Steps

### 1. Get a New Etherscan API Key

Since the old key `UP1PWX9D5Y4PWRVBQ5WY2Q9SQCN9WC8TVI` was exposed in git history:

1. Go to https://etherscan.io/myapikey
2. Log in or create an account
3. Generate a new API key
4. Copy the key for the next step

> **Note**: Etherscan V2 API supports multiple blockchains including BSC (chainId 56) and Ethereum (chainId 1) with a single API key.

### 2. Set Environment Variables in Vercel

**Option A: Via Vercel Dashboard (Recommended)**

1. Go to https://vercel.com/dashboard
2. Select your `pagocrypto` project
3. Go to Settings → Environment Variables
4. Add the following variables:

   | Name | Value | Environment |
   |------|-------|-------------|
   | `ETHERSCAN_API_KEY` | `your-new-etherscan-key` | Production, Preview, Development |

**Option B: Via Vercel CLI**

```bash
# Install Vercel CLI if not already installed
npm i -g vercel

# Set environment variables
vercel env add ETHERSCAN_API_KEY production
# Paste your key when prompted

# Optionally add for preview/development
vercel env add ETHERSCAN_API_KEY preview
vercel env add ETHERSCAN_API_KEY development
```

### 3. Deploy to Vercel

**If you already have Vercel connected to your git repo:**

Simply push to your main branch - Vercel will auto-deploy:

```bash
git add .
git commit -m "Add Etherscan proxy for secure API key management"
git push origin main
```

**If this is your first deployment:**

```bash
# From project root
vercel

# Follow prompts:
# - Link to existing project or create new one
# - Confirm settings
# - Deploy
```

### 4. Verify Deployment

After deployment, test the proxy endpoint:

```bash
curl -X POST https://pagocrypto.vercel.app/api/bscscan-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "chainId": 56,
    "queryParams": {
      "module": "proxy",
      "action": "eth_blockNumber"
    }
  }'
```

You should see a response like:
```json
{
  "status": "1",
  "message": "OK",
  "result": "0x..."
}
```

## Security Considerations

### What's Protected
✅ Etherscan API key is now server-side only
✅ Key is not in git history of new commits
✅ Key is not bundled in mobile/web app
✅ Telegram alerts for server errors (optional)

### What's Still Public
⚠️ The proxy endpoint URL is public
⚠️ Anyone can call your proxy (but only for allowed operations)
⚠️ Old API key is still in git history (should be rotated)

### Recommendations
1. **Rotate the old exposed key** on Etherscan to invalidate it
2. **Monitor usage** in your Etherscan account dashboard
3. **Set up Telegram alerts** (optional) to catch abuse early
4. **Consider rate limiting** if you see unexpected usage spikes

## API Endpoint

### Production
```
https://pagocrypto.vercel.app/api/bscscan-proxy
```

### Request Format
```json
{
  "chainId": 56,
  "queryParams": {
    "module": "account",
    "action": "tokentx",
    "address": "0x...",
    "contractaddress": "0x...",
    "startblock": "0",
    "endblock": "999999999",
    "sort": "asc",
    "page": "1",
    "offset": "1000"
  }
}
```

### Supported Chains
Etherscan V2 API supports multiple chains with a single API key:
- `56`: Binance Smart Chain (BSC) - currently used in your app
- `1`: Ethereum Mainnet
- Other chains supported by Etherscan V2

## Troubleshooting

### "API key not configured on server"
- Environment variable `ETHERSCAN_API_KEY` not set in Vercel
- Go to Vercel Dashboard → Settings → Environment Variables and add it

### "Upstream HTTP 401" or "Invalid API Key"
- The API key in Vercel is invalid or expired
- Generate a new key at https://etherscan.io/myapikey
- Update the `ETHERSCAN_API_KEY` variable in Vercel
- Redeploy (or wait for auto-deployment on next push)

### "Failed to reach upstream API"
- Vercel may be having network issues
- Check Etherscan API status at https://etherscan.io
- Check Vercel status at https://www.vercel-status.com

## Next Steps

After deployment is successful:

1. Test the Flutter app - it should automatically use the new proxy
2. Monitor the Vercel logs for any errors
3. **Important**: Rotate/delete the old exposed API key on Etherscan
4. Consider setting up Telegram alerts for production monitoring
