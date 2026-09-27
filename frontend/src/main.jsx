import React from "react";
import ReactDOM from "react-dom/client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";

import { createAppKit } from "@reown/appkit/react";
import { WagmiAdapter } from "@reown/appkit-adapter-wagmi";
import { polygonAmoy } from "@reown/appkit/networks";

import App from "./App";
import "./index.css";

const projectId = "83d85a607d4650081e6824c89f3a0a51";

const networks = [polygonAmoy];

const metadata = {
  name: "PolyLaunch",
  description: "Polygon Memecoin Launchpad",
  url: window.location.origin,
  icons: [],
};

const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
});

createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  metadata,

  features: {
    analytics: false,
    email: false,
    socials: false,
  },

  defaultNetwork: polygonAmoy,
});

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <WagmiProvider config={wagmiAdapter.wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>
);
