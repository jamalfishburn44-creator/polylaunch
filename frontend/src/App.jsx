import "./App.css";
import { useState } from "react";
import { BrowserProvider } from "ethers";

export default function App() {
const [account, setAccount] = useState("");

async function connectWallet() {
  if (!window.ethereum) {
    alert("Please install MetaMask.");
    return;
  }

  try {
    const provider = new BrowserProvider(window.ethereum);
    const accounts = await provider.send("eth_requestAccounts", []);
    setAccount(accounts[0]);
  } catch (err) {
    console.log(err);
  }
}
  return (
    <div className="app">

      <nav className="navbar">
        <h2>🚀 PolyLaunch</h2>
     <button
  className="connect"
  onClick={connectWallet}
>
  {account
    ? account.slice(0, 6) + "..." + account.slice(-4)
    : "Connect Wallet"}
</button>
      </nav>

      <div className="launch-container">

        <h1>Launch Your Token</h1>

        <input placeholder="Token Name" />

        <input placeholder="Symbol" />

        <input
          type="number"
          placeholder="Total Supply"
        />

        <textarea
          placeholder="Description"
          rows="5"
        />

        <input
          placeholder="Website (optional)"
        />

        <input
          placeholder="X / Twitter"
        />

        <input
          placeholder="Telegram"
        />

        <button className="launchButton">
          Launch Token ($4)
        </button>

      </div>

    </div>
  );
}
