import {
  useAccount,
  useDisconnect,
  usePublicClient,
  useWalletClient,
  useChainId,
} from "wagmi";

import {
  AppKitConnectButton,
  useAppKit,
} from "@reown/appkit/react";

import { useEffect, useState } from "react";

import {
  FACTORY_ADDRESS,
  USDC_ADDRESS,
  LAUNCH_FEE,
  ROUTER_ADDRESS,
} from "./contracts/config";

import { factoryAbi } from "./contracts/factoryAbi";
import { usdcAbi } from "./contracts/usdcAbi";
import { tokenAbi } from "./contracts/tokenAbi";
import { dexFactoryAbi } from "./contracts/dexFactoryAbi";
import { routerAbi } from "./contracts/routerAbi";
import { pairAbi } from "./contracts/pairAbi";
import {
  DEX_FACTORY_ADDRESS,
  AMOY_EXPLORER,
} from "./contracts/dexConfig";

const TOKEN_DECIMALS = 18;
const USDC_DECIMALS = 6;

const GAS_SETTINGS = {
  maxPriorityFeePerGas: 25_000_000_000n,
  maxFeePerGas: 30_000_000_000n,
};

export default function App() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();

  const { disconnect } = useDisconnect();

  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  const [totalProjects, setTotalProjects] = useState(0);
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedProject, setSelectedProject] = useState(null);
  const [dexPair, setDexPair] = useState(null);
  const [loadingDexPair, setLoadingDexPair] = useState(false);

  const [name, setName] = useState("");
  const [symbol, setSymbol] = useState("");
  const [description, setDescription] = useState("");
  const [website, setWebsite] = useState("");
  const [twitter, setTwitter] = useState("");
  const [telegram, setTelegram] = useState("");
  const [discord, setDiscord] = useState("");
  const [farcaster, setFarcaster] = useState("");
  const [supply, setSupply] = useState("1000000000");
  const [metadataURI, setMetadataURI] = useState("");
  const [tokenMetadata, setTokenMetadata] = useState(null);
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState("");
  const [bannerFile, setBannerFile] = useState(null);
  const [bannerPreview, setBannerPreview] = useState("");

  const [launching, setLaunching] = useState(false);
  const [message, setMessage] = useState("");

  const [tradeMode, setTradeMode] = useState("buy");
  const [tradeAmount, setTradeAmount] = useState("");
  const [tradeQuote, setTradeQuote] = useState(null);
  const [tokenBalance, setTokenBalance] = useState(0n);
  const [trading, setTrading] = useState(false);
  const [loadingQuote, setLoadingQuote] = useState(false);

  const { open } = useAppKit();

  async function loadProjects(showLoading = false) {
    if (!publicClient) return;

    try {
      if (showLoading) setLoading(true);

      const total = await publicClient.readContract({
        address: FACTORY_ADDRESS,
        abi: factoryAbi,
        functionName: "totalProjects",
      });

      const count = Number(total.toString());
      setTotalProjects(count);

      const loadedProjects = [];

      for (let i = 1; i <= count; i++) {
        const project = await publicClient.readContract({
          address: FACTORY_ADDRESS,
          abi: factoryAbi,
          functionName: "getProject",
          args: [BigInt(i)],
        });

        loadedProjects.push({
          id: project.id.toString(),
          creator: project.creator,
          token: project.token,
          name: project.name,
          symbol: project.symbol,
          metadataURI: project.metadataURI,
          totalSupply: project.totalSupply.toString(),
          createdAt: project.createdAt.toString(),
          active: project.active,
          reserveUSDC: project.reserveUSDC.toString(),
          reserveTokens: project.reserveTokens.toString(),
          liquidityTokens: project.liquidityTokens.toString(),
          sold: project.sold.toString(),
          graduated: project.graduated,
        });
      }

      setProjects(loadedProjects);

      if (selectedProject) {
        const updated = loadedProjects.find(
          (project) => project.id === selectedProject.id
        );

        if (updated) {
          setSelectedProject(updated);
        }
      }
    } catch (error) {
      console.error("Error loading projects:", error);

      setMessage(
        "Project loading error: " +
          (error.shortMessage || error.message)
      );
    } finally {
      if (showLoading) setLoading(false);
    }
  }

  async function loadDexPair(tokenAddress) {
    if (!publicClient || !tokenAddress) return;

    try {
      setLoadingDexPair(true);

      const pair = await publicClient.readContract({
        address: DEX_FACTORY_ADDRESS,
        abi: dexFactoryAbi,
        functionName: "getPair",
        args: [tokenAddress, USDC_ADDRESS],
      });

      const zeroAddress =
        "0x0000000000000000000000000000000000000000";

      setDexPair(
        pair.toLowerCase() === zeroAddress
          ? null
          : pair
      );
    } catch (error) {
      console.error("DEX pair lookup failed:", error);
      setDexPair(null);
    } finally {
      setLoadingDexPair(false);
    }
  }

  useEffect(() => {
    if (selectedProject?.graduated) {
      loadDexPair(selectedProject.token);
    } else {
      setDexPair(null);
    }
  }, [selectedProject, publicClient]);

  useEffect(() => {
    loadProjects(true);
  }, [publicClient]);
  useEffect(() => {
    if (!publicClient) return;

    const interval = setInterval(() => {
      loadProjects();
    }, 10000);

    return () => clearInterval(interval);
  }, [publicClient]);

  async function launchProject() {
    if (!walletClient || !address) {
      setMessage("Connect your wallet first.");
      return;
    }

    if (!name.trim() || !symbol.trim()) {
      setMessage("Enter a token name and symbol.");
      return;
    }

    if (!imageFile) {
      setMessage("Choose a token image first.");
      return;
    }

    try {
      setLaunching(true);
      setMessage("Uploading token image...");

      const imageFormData = new FormData();
      imageFormData.append("image", imageFile);

      const controller = new AbortController();
      const timeout = setTimeout(
        () => controller.abort(),
        30000
      );

      let imageResponse;

      try {
        imageResponse = await fetch(
          `http://${window.location.hostname}:3001/upload-image`,
          {
            method: "POST",
            body: imageFormData,
            signal: controller.signal,
          }
        );
      } catch (error) {
        if (error.name === "AbortError") {
          throw new Error(
            "Image upload timed out after 30 seconds."
          );
        }

        throw new Error(
          `Image upload connection failed: ${error.message}`
        );
      } finally {
        clearTimeout(timeout);
      }

      const imageResult = await imageResponse.json();

      if (!imageResponse.ok || !imageResult.success) {
        throw new Error(
          imageResult.error || "Image upload failed"
        );
      }

      const imageURI = imageResult.uri;

      let bannerURI = "";

      if (bannerFile) {
        setMessage("Uploading banner image...");

        const bannerFormData = new FormData();
        bannerFormData.append("image", bannerFile);

        const bannerController = new AbortController();
        const bannerTimeout = setTimeout(
          () => bannerController.abort(),
          30000
        );

        let bannerResponse;

        try {
          bannerResponse = await fetch(
            `http://${window.location.hostname}:3001/upload-image`,
            {
              method: "POST",
              body: bannerFormData,
              signal: bannerController.signal,
            }
          );
        } catch (error) {
          if (error.name === "AbortError") {
            throw new Error(
              "Banner upload timed out after 30 seconds."
            );
          }

          throw new Error(
            `Banner upload connection failed: ${error.message}`
          );
        } finally {
          clearTimeout(bannerTimeout);
        }

        const bannerResult =
          await bannerResponse.json();

        if (
          !bannerResponse.ok ||
          !bannerResult.success
        ) {
          throw new Error(
            bannerResult.error ||
              "Banner upload failed"
          );
        }

        bannerURI = bannerResult.uri;
      }

      setMessage("Uploading token metadata...");

      const metadataResponse = await fetch(
        `http://${window.location.hostname}:3001/upload-metadata`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            name: name.trim(),
            symbol: symbol.trim(),
            description: description.trim(),
            image: imageURI,
            website: website.trim(),
            twitter: twitter.trim(),
            telegram: telegram.trim(),
            discord: discord.trim(),
            farcaster: farcaster.trim(),
            banner: bannerURI,
          }),
        }
      );

      const metadataResult = await metadataResponse.json();

      if (
        !metadataResponse.ok ||
        !metadataResult.success
      ) {
        throw new Error(
          metadataResult.error ||
            "Metadata upload failed"
        );
      }

      const metadataURIValue = metadataResult.uri;

      setMetadataURI(metadataURIValue);

      setMessage("Checking USDC allowance...");

      const allowance =
        await publicClient.readContract({
          address: USDC_ADDRESS,
          abi: usdcAbi,
          functionName: "allowance",
          args: [address, FACTORY_ADDRESS],
        });

      const fee = BigInt(LAUNCH_FEE);

      if (allowance < fee) {
        setMessage("Approving 1 USDC launch fee...");

        const approveHash =
          await walletClient.writeContract({
            address: USDC_ADDRESS,
            abi: usdcAbi,
            functionName: "approve",
            args: [FACTORY_ADDRESS, fee],
            ...GAS_SETTINGS,
          });

        await publicClient.waitForTransactionReceipt({
          hash: approveHash,
        });
      }

      setMessage("Launching token...");

      const hash =
        await walletClient.writeContract({
          address: FACTORY_ADDRESS,
          abi: factoryAbi,
          functionName: "createProject",
          args: [
            name.trim(),
            symbol.trim(),
            metadataURIValue,
          ],
          ...GAS_SETTINGS,
        });

      await publicClient.waitForTransactionReceipt({
        hash,
      });

      setMessage("🚀 Token launched successfully!");

      setName("");
      setSymbol("");
      setDescription("");
      setWebsite("");
      setTwitter("");
      setTelegram("");
      setDiscord("");
      setFarcaster("");
      setSupply("1000000000");
      setMetadataURI("");
      setImageFile(null);
      setImagePreview("");
      setBannerFile(null);
      setBannerPreview("");

      await loadProjects();
    } catch (error) {
      console.error("Launch error:", error);

      setMessage(
        "Launch failed: " +
          (error.shortMessage || error.message)
      );
    } finally {
      setLaunching(false);
    }
  }

  function parseUSDCAmount(value) {
    if (!value || !/^\d+(\.\d{1,6})?$/.test(value)) {
      return null;
    }

    const [whole, fraction = ""] = value.split(".");
    const paddedFraction = fraction.padEnd(6, "0");

    return (
      BigInt(whole) * 10n ** 6n +
      BigInt(paddedFraction)
    );
  }

  function parseTokenAmount(value) {
    if (!value || !/^\d+$/.test(value)) {
      return null;
    }

    return BigInt(value) * 10n ** 18n;
  }

  function formatTokenAmount(value) {
    return (
      Number(value) / 10 ** TOKEN_DECIMALS
    ).toLocaleString(undefined, {
      maximumFractionDigits: 4,
    });
  }

  function formatUSDC(value) {
    return (
      Number(value) / 10 ** USDC_DECIMALS
    ).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 6,
    });
  }

  async function loadTradingData(project) {
    if (!publicClient || !address || !project) return;

    try {
      const balance =
        await publicClient.readContract({
          address: project.token,
          abi: tokenAbi,
          functionName: "balanceOf",
          args: [address],
        });

      setTokenBalance(balance);
    } catch (error) {
      console.error(
        "Token balance error:",
        error
      );

      setTokenBalance(0n);
    }
  }

  async function updateTradeQuote(value = tradeAmount) {
    setTradeQuote(null);

    if (!publicClient || !selectedProject) return;

    const graduated = selectedProject.graduated;

    const amount = graduated
      ? tradeMode === "buy"
        ? parseUSDCAmount(value)
        : parseTokenAmount(value)
      : parseTokenAmount(value);

    if (amount === null || amount <= 0n) {
      return;
    }

    try {
      setLoadingQuote(true);

      if (!graduated) {
        const quote = await publicClient.readContract({
          address: FACTORY_ADDRESS,
          abi: factoryAbi,
          functionName:
            tradeMode === "buy"
              ? "getBuyQuote"
              : "getSellQuote",
          args: [
            BigInt(selectedProject.id),
            amount,
          ],
        });

        setTradeQuote(quote);
        return;
      }

      const pair = await publicClient.readContract({
        address: DEX_FACTORY_ADDRESS,
        abi: dexFactoryAbi,
        functionName: "getPair",
        args: [
          selectedProject.token,
          USDC_ADDRESS,
        ],
      });

      if (
        !pair ||
        pair ===
          "0x0000000000000000000000000000000000000000"
      ) {
        throw new Error("DEX pair not found");
      }

      const token0 = await publicClient.readContract({
        address: pair,
        abi: pairAbi,
        functionName: "token0",
      });

      const reserves = await publicClient.readContract({
        address: pair,
        abi: pairAbi,
        functionName: "getReserves",
      });

      const reserve0 = reserves[0];
      const reserve1 = reserves[1];

      const tokenIn =
        tradeMode === "buy"
          ? USDC_ADDRESS
          : selectedProject.token;

      const tokenOut =
        tradeMode === "buy"
          ? selectedProject.token
          : USDC_ADDRESS;

      const reserveIn =
        tokenIn.toLowerCase() === token0.toLowerCase()
          ? reserve0
          : reserve1;

      const reserveOut =
        tokenOut.toLowerCase() === token0.toLowerCase()
          ? reserve0
          : reserve1;

      const quote = await publicClient.readContract({
        address: ROUTER_ADDRESS,
        abi: routerAbi,
        functionName: "getAmountOutForPair",
        args: [
          pair,
          amount,
          reserveIn,
          reserveOut,
        ],
      });

      setTradeQuote(quote);
    } catch (error) {
      console.error("Quote error:", error);
      setTradeQuote(null);
    } finally {
      setLoadingQuote(false);
    }
  }

  useEffect(() => {
    if (!selectedProject) return;

    setTradeAmount("");
    setTradeQuote(null);

    loadTradingData(selectedProject);
  }, [
    selectedProject,
    address,
    publicClient,
  ]);

  useEffect(() => {
    if (!selectedProject || !tradeAmount) {
      setTradeQuote(null);
      return;
    }

    const timer = setTimeout(() => {
      updateTradeQuote();
    }, 250);

    return () => clearTimeout(timer);
  }, [
    tradeAmount,
    tradeMode,
    selectedProject,
  ]);

  async function executeTrade() {
    if (!walletClient || !address) {
      setMessage("Connect your wallet first.");
      return;
    }

    if (!selectedProject) {
      return;
    }

    try {
      setTrading(true);
      setMessage("");

      if (selectedProject.graduated) {
        const amount =
          tradeMode === "buy"
            ? parseUSDCAmount(tradeAmount)
            : parseTokenAmount(tradeAmount);

        if (amount === null || amount <= 0n) {
          setMessage(
            tradeMode === "buy"
              ? "Enter a valid USDC amount."
              : "Enter a whole-number token amount."
          );
          return;
        }

        const tokenIn =
          tradeMode === "buy"
            ? USDC_ADDRESS
            : selectedProject.token;

        const tokenOut =
          tradeMode === "buy"
            ? selectedProject.token
            : USDC_ADDRESS;

        const pair = await publicClient.readContract({
          address: DEX_FACTORY_ADDRESS,
          abi: dexFactoryAbi,
          functionName: "getPair",
          args: [
            selectedProject.token,
            USDC_ADDRESS,
          ],
        });

        if (
          !pair ||
          pair ===
            "0x0000000000000000000000000000000000000000"
        ) {
          throw new Error("DEX pair not found.");
        }

        const token0 = await publicClient.readContract({
          address: pair,
          abi: pairAbi,
          functionName: "token0",
        });

        const reserves = await publicClient.readContract({
          address: pair,
          abi: pairAbi,
          functionName: "getReserves",
        });

        const reserve0 = reserves[0];
        const reserve1 = reserves[1];

        const reserveIn =
          tokenIn.toLowerCase() === token0.toLowerCase()
            ? reserve0
            : reserve1;

        const reserveOut =
          tokenOut.toLowerCase() === token0.toLowerCase()
            ? reserve0
            : reserve1;

        const quote =
          await publicClient.readContract({
            address: ROUTER_ADDRESS,
            abi: routerAbi,
            functionName: "getAmountOutForPair",
            args: [
              pair,
              amount,
              reserveIn,
              reserveOut,
            ],
          });

        if (quote <= 0n) {
          throw new Error(
            "Insufficient DEX liquidity."
          );
        }

        const amountOutMin =
          (quote * 99n) / 100n;

        const balanceAddress =
          tradeMode === "buy"
            ? USDC_ADDRESS
            : selectedProject.token;

        const balanceAbi =
          tradeMode === "buy"
            ? usdcAbi
            : tokenAbi;

        const balance =
          await publicClient.readContract({
            address: balanceAddress,
            abi: balanceAbi,
            functionName: "balanceOf",
            args: [address],
          });

        if (balance < amount) {
          throw new Error(
            tradeMode === "buy"
              ? `Insufficient USDC. Need ${formatUSDC(amount)} USDC.`
              : `Insufficient ${selectedProject.symbol} balance.`
          );
        }

        const allowance =
          await publicClient.readContract({
            address: balanceAddress,
            abi: balanceAbi,
            functionName: "allowance",
            args: [
              address,
              ROUTER_ADDRESS,
            ],
          });

        if (allowance < amount) {
          setMessage(
            tradeMode === "buy"
              ? "Approving USDC for the DEX..."
              : `Approving ${selectedProject.symbol} for the DEX...`
          );

          const approveHash =
            await walletClient.writeContract({
              address: balanceAddress,
              abi: balanceAbi,
              functionName: "approve",
              args: [
                ROUTER_ADDRESS,
                amount,
              ],
              ...GAS_SETTINGS,
            });

          await publicClient.waitForTransactionReceipt({
            hash: approveHash,
          });
        }

        setMessage(
          tradeMode === "buy"
            ? `Buying ${selectedProject.symbol} on the DEX...`
            : `Selling ${selectedProject.symbol} on the DEX...`
        );

        const deadline = BigInt(
          Math.floor(Date.now() / 1000) + 300
        );

        const hash =
          await walletClient.writeContract({
            address: ROUTER_ADDRESS,
            abi: routerAbi,
            functionName:
              "swapExactTokensForTokens",
            args: [
              tokenIn,
              tokenOut,
              amount,
              amountOutMin,
              address,
              deadline,
            ],
            ...GAS_SETTINGS,
          });

        const receipt =
          await publicClient.waitForTransactionReceipt({
            hash,
          });

        if (receipt.status !== "success") {
          throw new Error(
            `DEX transaction reverted. Tx: ${hash}`
          );
        }

        setMessage(
          tradeMode === "buy"
            ? `✅ Bought approximately ${formatTokenAmount(quote)} ${selectedProject.symbol}`
            : `✅ Sold ${formatTokenAmount(amount)} ${selectedProject.symbol} for approximately ${formatUSDC(quote)} USDC`
        );
      } else {
        const amount = parseTokenAmount(
          tradeAmount
        );

        if (amount === null || amount <= 0n) {
          setMessage(
            "Enter a whole-number token amount."
          );
          return;
        }

        if (tradeMode === "buy") {
          setMessage("Getting buy quote...");

          const cost =
            await publicClient.readContract({
              address: FACTORY_ADDRESS,
              abi: factoryAbi,
              functionName: "getBuyQuote",
              args: [
                BigInt(selectedProject.id),
                amount,
              ],
            });

          const usdcBalance =
            await publicClient.readContract({
              address: USDC_ADDRESS,
              abi: usdcAbi,
              functionName: "balanceOf",
              args: [address],
            });

          if (usdcBalance < cost) {
            throw new Error(
              `Insufficient USDC. Need ${formatUSDC(cost)} USDC.`
            );
          }

          const allowance =
            await publicClient.readContract({
              address: USDC_ADDRESS,
              abi: usdcAbi,
              functionName: "allowance",
              args: [
                address,
                FACTORY_ADDRESS,
              ],
            });

          if (allowance < cost) {
            setMessage(
              "Approving USDC for this trade..."
            );

            const approveHash =
              await walletClient.writeContract({
                address: USDC_ADDRESS,
                abi: usdcAbi,
                functionName: "approve",
                args: [
                  FACTORY_ADDRESS,
                  cost,
                ],
                ...GAS_SETTINGS,
              });

            await publicClient.waitForTransactionReceipt({
              hash: approveHash,
            });
          }

          setMessage(
            `Buying ${formatTokenAmount(amount)} ${selectedProject.symbol}...`
          );

          const hash =
            await walletClient.writeContract({
              address: FACTORY_ADDRESS,
              abi: factoryAbi,
              functionName: "buy",
              args: [
                BigInt(selectedProject.id),
                amount,
              ],
              ...GAS_SETTINGS,
            });

          const receipt =
            await publicClient.waitForTransactionReceipt({
              hash,
            });

          if (receipt.status !== "success") {
            throw new Error(
              `Buy transaction reverted. Tx: ${hash}`
            );
          }

          setMessage(
            `✅ Bought ${formatTokenAmount(amount)} ${selectedProject.symbol}`
          );
        } else {
          if (amount > tokenBalance) {
            throw new Error(
              `Insufficient ${selectedProject.symbol} balance.`
            );
          }

          setMessage("Getting sell quote...");

          const payout =
            await publicClient.readContract({
              address: FACTORY_ADDRESS,
              abi: factoryAbi,
              functionName: "getSellQuote",
              args: [
                BigInt(selectedProject.id),
                amount,
              ],
            });

          const allowance =
            await publicClient.readContract({
              address: selectedProject.token,
              abi: tokenAbi,
              functionName: "allowance",
              args: [
                address,
                FACTORY_ADDRESS,
              ],
            });

          if (allowance < amount) {
            setMessage(
              `Approving ${selectedProject.symbol} for sale...`
            );

            const approveHash =
              await walletClient.writeContract({
                address: selectedProject.token,
                abi: tokenAbi,
                functionName: "approve",
                args: [
                  FACTORY_ADDRESS,
                  amount,
                ],
                ...GAS_SETTINGS,
              });

            await publicClient.waitForTransactionReceipt({
              hash: approveHash,
            });
          }

          setMessage(
            `Selling ${formatTokenAmount(amount)} ${selectedProject.symbol}...`
          );

          const hash =
            await walletClient.writeContract({
              address: FACTORY_ADDRESS,
              abi: factoryAbi,
              functionName: "sell",
              args: [
                BigInt(selectedProject.id),
                amount,
              ],
              ...GAS_SETTINGS,
            });

          const receipt =
            await publicClient.waitForTransactionReceipt({
              hash,
            });

          if (receipt.status !== "success") {
            throw new Error(
              `Sell transaction reverted. Tx: ${hash}`
            );
          }

          setMessage(
            `✅ Sold ${formatTokenAmount(amount)} ${selectedProject.symbol} for ${formatUSDC(payout)} USDC`
          );
        }
      }

      setTradeAmount("");
      setTradeQuote(null);
      await loadProjects();
    } catch (error) {
      console.error("Trade error:", error);
      setMessage(
        error?.shortMessage ||
          error?.message ||
          "Trade failed."
      );
    } finally {
      setTrading(false);
    }
  }

  useEffect(() => {
    if (selectedProject?.metadataURI) {
      loadTokenMetadata(
        selectedProject.metadataURI
      );
    } else {
      setTokenMetadata(null);
    }
  }, [selectedProject]);

  if (selectedProject) {
    return (
      <div
        style={{
          minHeight: "100vh",
          background: "#0f172a",
          color: "white",
          padding: "25px 15px",
          textAlign: "center",
          fontFamily: "Arial",
        }}
      >
        <div
          style={{
            maxWidth: "650px",
            margin: "0 auto",
          }}
        >
          <button
            onClick={() =>
              setSelectedProject(null)
            }
            style={{
              padding: "10px 20px",
              fontSize: "16px",
              cursor: "pointer",
              marginBottom: "20px",
            }}
          >
            ← Back
          </button>

          <h1>{selectedProject.name}</h1>

          <h2>
            ${selectedProject.symbol}
          </h2>

          {tokenMetadata?.banner && (
            <img
              src={
                tokenMetadata.banner.startsWith("ipfs://")
                  ? `https://gateway.pinata.cloud/ipfs/${tokenMetadata.banner.slice(7)}`
                  : tokenMetadata.banner
              }
              alt={`${selectedProject.name} banner`}
              style={{
                width: "100%",
                maxHeight: "240px",
                objectFit: "cover",
                borderRadius: "18px",
                marginTop: "16px",
              }}
            />
          )}

          {tokenMetadata && (
            <div
              style={{
                background: "#1e293b",
                borderRadius: "16px",
                padding: "20px",
                marginTop: "20px",
                textAlign: "left",
              }}
            >
              {tokenMetadata.description && (
                <p
                  style={{
                    fontSize: "17px",
                    lineHeight: "1.6",
                    marginTop: 0,
                  }}
                >
                  {tokenMetadata.description}
                </p>
              )}

              <div
                style={{
                  display: "flex",
                  flexWrap: "wrap",
                  gap: "10px",
                }}
              >
                {[
                  ["🌐 Website", tokenMetadata.website],
                  ["𝕏 X", tokenMetadata.twitter],
                  ["✈️ Telegram", tokenMetadata.telegram],
                  ["💬 Discord", tokenMetadata.discord],
                  ["🟣 Farcaster", tokenMetadata.farcaster],
                ]
                  .filter(([, url]) => url)
                  .map(([label, url]) => (
                    <a
                      key={label}
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      style={{
                        padding: "9px 13px",
                        borderRadius: "10px",
                        background: "#334155",
                        color: "white",
                        textDecoration: "none",
                      }}
                    >
                      {label}
                    </a>
                  ))}
              </div>
            </div>
          )}

          <div
            style={{
              background: "#1e293b",
              borderRadius: "16px",
              padding: "20px",
              marginTop: "20px",
            }}
          >
            <p>
              <strong>Token:</strong>{" "}
              {shortenAddress(
                selectedProject.token
              )}
            </p>

            <p>
              <strong>Creator:</strong>{" "}
              {shortenAddress(
                selectedProject.creator
              )}
            </p>

            <p>
              <strong>Total Supply:</strong>{" "}
              {Number(
                BigInt(
                  selectedProject.totalSupply
                ) / 10n ** 18n
              ).toLocaleString()}
            </p>

            <p>
              <strong>Tokens Sold:</strong>{" "}
              {formatTokenAmount(
                BigInt(
                  selectedProject.sold
                )
              )}
            </p>

            <p>
              <strong>USDC Reserve:</strong>{" "}
              {formatUSDC(
                BigInt(
                  selectedProject.reserveUSDC
                )
              )}{" "}
              USDC
            </p>

            <p>
              <strong>Status:</strong>{" "}
              {selectedProject.graduated
                ? "🎓 Graduated"
                : selectedProject.active
                ? "🟢 Active"
                : "🔴 Inactive"}
            </p>

            {!selectedProject.graduated && (
              <div
                style={{
                  marginTop: "16px",
                  padding: "16px",
                  borderRadius: "14px",
                  background: "#172033",
                  border: "1px solid #334155",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    marginBottom: "8px",
                  }}
                >
                  <strong>Graduation Progress</strong>
                  <span>150 USDC</span>
                </div>

                <div
                  style={{
                    height: "12px",
                    width: "100%",
                    background: "#0f172a",
                    borderRadius: "999px",
                    overflow: "hidden",
                  }}
                >
                  <div
                    style={{
                      height: "100%",
                      width: `${Math.min(
                        100,
                        (Number(selectedProject.reserveUSDC) /
                          150000000) *
                          100
                      )}%`,
                      background: "#8b5cf6",
                      borderRadius: "999px",
                      transition: "width 0.4s ease",
                    }}
                  />
                </div>

                <p style={{ marginBottom: 0 }}>
                  {formatUSDC(
                    BigInt(selectedProject.reserveUSDC)
                  )}{" "}
                  / 150 USDC
                </p>
              </div>
            )}

            {selectedProject.graduated && (
              <div
                style={{
                  marginTop: "16px",
                  padding: "16px",
                  borderRadius: "14px",
                  background: "#172033",
                  border: "1px solid #334155",
                }}
              >
                <h3 style={{ marginTop: 0 }}>
                  🎓 Graduation Complete
                </h3>

                <p>🔒 Liquidity is locked for 365 days.</p>

                <p>
                  🚫 Bonding-curve trading is closed.
                </p>

                <p>
                  🔄 Trading continues through the DEX liquidity pool.
                </p>

                <div
                  style={{
                    marginTop: "14px",
                    paddingTop: "14px",
                    borderTop: "1px solid #334155",
                  }}
                >
                  <strong>DEX Pair:</strong>

                  {loadingDexPair ? (
                    <p>Loading pair...</p>
                  ) : dexPair ? (
                    <>
                      <p
                        style={{
                          wordBreak: "break-all",
                          marginBottom: "10px",
                        }}
                      >
                        {dexPair}
                      </p>

                      <a
                        href={`${AMOY_EXPLORER}/address/${dexPair}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{
                          display: "inline-block",
                          padding: "10px 14px",
                          borderRadius: "10px",
                          textDecoration: "none",
                          background: "#334155",
                          color: "white",
                        }}
                      >
                        🔎 View Pair
                      </a>
                    </>
                  ) : (
                    <p>Pair not available yet.</p>
                  )}
                </div>
              </div>
            )}
          </div>

          {isConnected &&
            (selectedProject.active || selectedProject.graduated) && (
              <div
                style={{
                  background: "#1e293b",
                  borderRadius: "18px",
                  padding: "20px",
                  marginTop: "20px",
                  textAlign: "left",
                }}
              >
                <h2
                  style={{
                    textAlign: "center",
                    marginTop: 0,
                  }}
                >
                  Trade ${selectedProject.symbol}
                </h2>

                <div
                  style={{
                    display: "flex",
                    gap: "10px",
                    marginBottom: "18px",
                  }}
                >
                  <button
                    onClick={() =>
                      setTradeMode("buy")
                    }
                    style={{
                      flex: 1,
                      padding: "13px",
                      fontSize: "17px",
                      fontWeight: "bold",
                      cursor: "pointer",
                      background:
                        tradeMode === "buy"
                          ? "#22c55e"
                          : "#334155",
                      color: "white",
                      border: "none",
                      borderRadius: "10px",
                    }}
                  >
                    Buy
                  </button>

                  <button
                    onClick={() =>
                      setTradeMode("sell")
                    }
                    style={{
                      flex: 1,
                      padding: "13px",
                      fontSize: "17px",
                      fontWeight: "bold",
                      cursor: "pointer",
                      background:
                        tradeMode === "sell"
                          ? "#ef4444"
                          : "#334155",
                      color: "white",
                      border: "none",
                      borderRadius: "10px",
                    }}
                  >
                    Sell
                  </button>
                </div>

                <p
                  style={{
                    color: "#cbd5e1",
                    fontSize: "14px",
                  }}
                >
                  Your balance:{" "}
                  {formatTokenAmount(
                    tokenBalance
                  )}{" "}
                  {selectedProject.symbol}
                </p>

                <label
                  style={{
                    display: "block",
                    marginBottom: "8px",
                    fontWeight: "bold",
                  }}
                >
                  Token amount
                </label>

                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder={`Amount of ${selectedProject.symbol}`}
                  value={tradeAmount}
                  onChange={(e) =>
                    setTradeAmount(
                      e.target.value
                    )
                  }
                  style={{
                    width: "100%",
                    padding: "15px",
                    boxSizing:
                      "border-box",
                    borderRadius: "10px",
                    border:
                      "1px solid #475569",
                    background: "#0f172a",
                    color: "white",
                    fontSize: "17px",
                    marginBottom: "15px",
                  }}
                />

                {loadingQuote && (
                  <p
                    style={{
                      color: "#94a3b8",
                    }}
                  >
                    Calculating quote...
                  </p>
                )}

                {tradeQuote !== null && (
                  <div
                    style={{
                      background: "#0f172a",
                      borderRadius: "10px",
                      padding: "15px",
                      marginBottom: "15px",
                    }}
                  >
                    <strong>
                      {tradeMode === "buy"
                        ? "You pay"
                        : "You receive"}
                    </strong>

                    <div
                      style={{
                        fontSize: "24px",
                        fontWeight: "bold",
                        marginTop: "5px",
                      }}
                    >
                      {formatUSDC(
                        tradeQuote
                      )}{" "}
                      USDC
                    </div>
                  </div>
                )}

                <button
                  onClick={executeTrade}
                  disabled={
                    trading ||
                    !tradeAmount ||
                    !isConnected
                  }
                  style={{
                    width: "100%",
                    padding: "15px",
                    fontSize: "18px",
                    fontWeight: "bold",
                    cursor: trading
                      ? "wait"
                      : "pointer",
                    border: "none",
                    borderRadius: "10px",
                    background:
                      tradeMode === "buy"
                        ? "#22c55e"
                        : "#ef4444",
                    color: "white",
                  }}
                >
                  {trading
                    ? "Processing..."
                    : tradeMode === "buy"
                    ? `Buy ${selectedProject.symbol}`
                    : `Sell ${selectedProject.symbol}`}
                </button>

                {message && (
                  <p
                    style={{
                      marginTop: "15px",
                      fontSize: "14px",
                      wordBreak: "break-word",
                    }}
                  >
                    {message}
                  </p>
                )}
              </div>
            )}

          {!isConnected && (
            <div
              style={{
                marginTop: "20px",
              }}
            >
              <AppKitConnectButton />
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div
      style={{
        background: "#0f172a",
        color: "white",
        minHeight: "100vh",
        padding: "40px 20px",
        fontFamily: "Arial",
      }}
    >
      <div
        style={{
          maxWidth: "1000px",
          margin: "0 auto",
        }}
      >
        <h1
          style={{
            fontSize: "48px",
          }}
        >
          🚀 PolyLaunch
        </h1>

        <p
          style={{
            fontSize: "22px",
          }}
        >
          Polygon Memecoin Launchpad
        </p>

        <h2>
          Total Projects:{" "}
          {totalProjects}
        </h2>

        {!isConnected ? (
          <AppKitConnectButton />
        ) : (
          <div>
            <p>
              Connected:{" "}
              {shortenAddress(address)}
            </p>

            <p>
              Chain ID: {chainId}
            </p>

            <button
              onClick={() => disconnect()}
              style={{
                padding: "10px 18px",
                cursor: "pointer",
              }}
            >
              Disconnect
            </button>
          </div>
        )}

        <hr
          style={{
            margin: "40px 0",
          }}
        />

        <h2>🚀 Launch a Token</h2>

        <div
          style={{
            background: "#1e293b",
            padding: "25px",
            borderRadius: "16px",
            maxWidth: "600px",
          }}
        >
          <div
            style={{
              marginBottom: "20px",
            }}
          >
            <div
              style={{
                fontSize: "13px",
                fontWeight: "800",
                letterSpacing: "1px",
                opacity: 0.7,
                marginBottom: "14px",
              }}
            >
              TOKEN DETAILS
            </div>

            <label
              style={{
                display: "block",
                marginBottom: "10px",
                fontWeight: "bold",
              }}
            >
              Token Image
            </label>

            <input
              type="file"
              accept="image/png,image/jpeg,image/webp,image/gif"
              onChange={(e) => {
                const file =
                  e.target.files?.[0];

                if (!file) return;

                setImageFile(file);
                setImagePreview(
                  URL.createObjectURL(file)
                );
              }}
              style={{
                width: "100%",
                marginBottom: "12px",
              }}
            />

            {imagePreview && (
              <img
                src={imagePreview}
                alt="Token preview"
                style={{
                  width: "120px",
                  height: "120px",
                  objectFit: "cover",
                  borderRadius: "16px",
                  display: "block",
                }}
              />
            )}
          </div>

          <input
            placeholder="Token name"
            value={name}
            onChange={(e) =>
              setName(e.target.value)
            }
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
            }}
          />

          <input
            placeholder="Token symbol"
            value={symbol}
            onChange={(e) =>
              setSymbol(e.target.value)
            }
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
            }}
          />

          <textarea
            placeholder="Description"
            value={description}
            onChange={(e) =>
              setDescription(e.target.value)
            }
            rows={4}
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
              resize: "vertical",
            }}
          />

          <div
            style={{
              fontSize: "13px",
              fontWeight: "800",
              letterSpacing: "1px",
              opacity: 0.7,
              marginTop: "24px",
              marginBottom: "14px",
            }}
          >
            SOCIAL LINKS
          </div>

          <input
            placeholder="Website (optional)"
            value={website}
            onChange={(e) =>
              setWebsite(e.target.value)
            }
            type="url"
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
            }}
          />

          <input
            placeholder="X / Twitter (optional)"
            value={twitter}
            onChange={(e) =>
              setTwitter(e.target.value)
            }
            type="url"
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
            }}
          />

          <input
            placeholder="Telegram (optional)"
            value={telegram}
            onChange={(e) =>
              setTelegram(e.target.value)
            }
            type="url"
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
            }}
          />

          <input
            placeholder="Discord (optional)"
            value={discord}
            onChange={(e) =>
              setDiscord(e.target.value)
            }
            type="url"
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
            }}
          />

          <input
            placeholder="Farcaster (optional)"
            value={farcaster}
            onChange={(e) =>
              setFarcaster(e.target.value)
            }
            type="url"
            style={{
              width: "100%",
              padding: "14px",
              marginBottom: "12px",
              boxSizing: "border-box",
            }}
          />

          <div
            style={{
              fontSize: "13px",
              fontWeight: "800",
              letterSpacing: "1px",
              opacity: 0.7,
              marginTop: "24px",
              marginBottom: "14px",
            }}
          >
            LAUNCH DETAILS
          </div>

          <div
            style={{
              background: "#0f172a",
              padding: "14px",
              borderRadius: "10px",
              marginBottom: "12px",
            }}
          >
            <strong>Total Supply</strong>
            <div
              style={{
                marginTop: "6px",
                fontSize: "18px",
              }}
            >
              1,000,000,000 tokens
            </div>
            <small
              style={{
                opacity: 0.7,
              }}
            >
              Fixed supply for PolyLaunch tokens
            </small>
          </div>

          <div
            style={{
              fontSize: "13px",
              fontWeight: "800",
              letterSpacing: "1px",
              opacity: 0.7,
              marginTop: "24px",
              marginBottom: "14px",
            }}
          >
            BRANDING
          </div>

          <div
            style={{
              marginBottom: "20px",
            }}
          >
            <label
              style={{
                display: "block",
                marginBottom: "10px",
                fontWeight: "bold",
              }}
            >
              Banner Image — Optional
            </label>

            <input
              type="file"
              accept="image/png,image/jpeg,image/webp,image/gif"
              onChange={(e) => {
                const file =
                  e.target.files?.[0];

                if (!file) return;

                setBannerFile(file);
                setBannerPreview(
                  URL.createObjectURL(file)
                );
              }}
              style={{
                width: "100%",
                marginBottom: "12px",
              }}
            />

            {bannerPreview && (
              <img
                src={bannerPreview}
                alt="Banner preview"
                style={{
                  width: "100%",
                  maxHeight: "180px",
                  objectFit: "cover",
                  borderRadius: "12px",
                  display: "block",
                }}
              />
            )}
          </div>

          <button
            onClick={launchProject}
            disabled={
              !isConnected || launching
            }
            style={{
              width: "100%",
              padding: "14px",
              fontSize: "18px",
              cursor: "pointer",
            }}
          >
            {launching
              ? "Launching..."
              : "🚀 Launch Token — 1 USDC"}
          </button>

          {message && (
            <p
              style={{
                marginTop: "20px",
              }}
            >
              {message}
            </p>
          )}
        </div>

        <hr
          style={{
            margin: "40px 0",
          }}
        />

        <h2>🚀 Live Projects</h2>

        {loading && (
          <p>Loading projects...</p>
        )}

        {!loading &&
          projects.length === 0 && (
            <p>
              No projects launched yet.
            </p>
          )}

        <div
          style={{
            display: "grid",
            gridTemplateColumns:
              "repeat(auto-fit, minmax(280px, 1fr))",
            gap: "20px",
            marginTop: "20px",
          }}
        >
          {projects.map((project) => (
            <div
              key={project.id}
              onClick={() =>
                setSelectedProject(
                  project
                )
              }
              style={{
                background: "#1e293b",
                borderRadius: "16px",
                padding: "24px",
                border:
                  "1px solid #334155",
                cursor: "pointer",
              }}
            >
              <h3>
                {project.name}
              </h3>

              <p>
                ${project.symbol}
              </p>

              <p>
                Sold:{" "}
                {(
                  BigInt(
                    project.sold
                  ) /
                  1000000000000000000n
                ).toLocaleString()}
              </p>

              <p>
                Reserve:{" "}
                {(
                  Number(
                    BigInt(
                      project.reserveUSDC
                    )
                  ) / 1e6
                ).toFixed(2)}
                USDC
              </p>

              <p>
                {project.graduated
                  ? "🎓 Graduated"
                  : project.active
                  ? "🟢 Active"
                  : "🔴 Inactive"}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
