import { BrowserProvider, Contract } from "ethers";

export const FACTORY_ADDRESS =
  "0xfebABcAe2580daF7164A139c9b44aa53E31087c9";

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
