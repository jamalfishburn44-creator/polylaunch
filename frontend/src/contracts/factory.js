import { BrowserProvider, Contract } from "ethers";

export const FACTORY_ADDRESS =
  "0x3f34D9b50E36e426E7A880d676fB25dB56EF86ad";

export const FACTORY_ABI = [
  "function createProject(string name,string symbol,string metadataURI)",
  "function totalProjects() view returns (uint256)",
  "function treasury() view returns (address)",
  "function usdc() view returns (address)"
];

export async function getFactory() {
  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  return new Contract(FACTORY_ADDRESS, FACTORY_ABI, signer);
}
