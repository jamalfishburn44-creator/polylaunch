import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  parseGwei,
} from "viem";
import { polygonAmoy } from "viem/chains";

const FACTORY = "0x46ccC7eB6b28A9e2391B71dd203e3D89Fb905a41";
const ROUTER = "0x1AF405601CDCBAbA000c4D7A233d923cbfc083eC";

const REQUIRED_WALLET =
  "0x5E0f7e8a96652D656A50811b94b88798B827b33f";

const abi = [
  {
    type: "function",
    name: "setRouter",
    stateMutability: "nonpayable",
    inputs: [
      {
        name: "_router",
        type: "address",
      },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "router",
    stateMutability: "view",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
      },
    ],
  },
];

const app = document.getElementById("app");

app.innerHTML = `
  <div style="
    max-width:600px;
    margin:40px auto;
    padding:24px;
    font-family:Arial,sans-serif;
  ">
    <h1>PolyLaunch Router Setup</h1>

    <p>
      This temporary page configures the DEX Factory router.
    </p>

    <p>
      <strong>Required wallet:</strong><br>
      ${REQUIRED_WALLET}
    </p>

    <p>
      <strong>Router:</strong><br>
      ${ROUTER}
    </p>

    <button id="connect" style="padding:14px 20px;">
      Connect MetaMask
    </button>

    <button id="setup" disabled style="padding:14px 20px;margin-left:10px;">
      Set Router
    </button>

    <pre id="status" style="
      margin-top:20px;
      padding:15px;
      background:#eee;
      white-space:pre-wrap;
    ">Not connected.</pre>
  </div>
`;

const status = document.getElementById("status");
const connectButton = document.getElementById("connect");
const setupButton = document.getElementById("setup");

let walletClient;
let publicClient;
let account;

function setStatus(message) {
  status.textContent = message;
}

connectButton.onclick = async () => {
  try {
    if (!window.ethereum) {
      throw new Error("MetaMask was not detected.");
    }

    walletClient = createWalletClient({
      chain: polygonAmoy,
      transport: custom(window.ethereum),
    });

    publicClient = createPublicClient({
      chain: polygonAmoy,
      transport: http(
        "https://polygon-amoy-bor-rpc.publicnode.com"
      ),
    });

    await walletClient.requestAddresses();

    const addresses = await walletClient.getAddresses();

    account = addresses[0];

    if (account.toLowerCase() !== REQUIRED_WALLET.toLowerCase()) {
      throw new Error(
        `WRONG WALLET.\n\nConnected:\n${account}\n\nRequired:\n${REQUIRED_WALLET}`
      );
    }

    await walletClient.switchChain({
      id: 80002,
    });

    const currentRouter = await publicClient.readContract({
      address: FACTORY,
      abi,
      functionName: "router",
    });

    setStatus(
      `Connected correctly.\n\n` +
      `Wallet:\n${account}\n\n` +
      `Network: Polygon Amoy\n\n` +
      `Current router:\n${currentRouter}`
    );

    connectButton.disabled = true;
    setupButton.disabled = false;

  } catch (error) {
    setStatus(
      `ERROR:\n\n${error.shortMessage || error.message || error}`
    );
  }
};

setupButton.onclick = async () => {
  try {
    setupButton.disabled = true;

    setStatus("Simulating setRouter...");

    await publicClient.simulateContract({
      address: FACTORY,
      abi,
      functionName: "setRouter",
      args: [ROUTER],
      account,
    });

    setStatus(
      "Simulation succeeded.\n\n" +
      "Waiting for MetaMask confirmation..."
    );

    const hash = await walletClient.writeContract({
      address: FACTORY,
      abi,
      functionName: "setRouter",
      args: [ROUTER],
      account,

      maxPriorityFeePerGas: parseGwei("25"),
      maxFeePerGas: parseGwei("30"),
      gas: 100_000n,
    });

    setStatus(
      `Transaction submitted.\n\n` +
      `TX:\n${hash}\n\n` +
      `Waiting for confirmation...`
    );

    const receipt =
      await publicClient.waitForTransactionReceipt({
        hash,
      });

    if (receipt.status !== "success") {
      throw new Error(
        `Transaction reverted.\n\nTX:\n${hash}`
      );
    }

    const newRouter = await publicClient.readContract({
      address: FACTORY,
      abi,
      functionName: "router",
    });

    setStatus(
      `SUCCESS!\n\n` +
      `Transaction:\n${hash}\n\n` +
      `Factory router is now:\n${newRouter}`
    );

  } catch (error) {
    setStatus(
      `ERROR:\n\n${error.shortMessage || error.message || error}`
    );

    setupButton.disabled = false;
  }
};
