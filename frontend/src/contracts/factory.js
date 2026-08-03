import { BrowserProvider, Contract } from "ethers";

export const FACTORY_ADDRESS = "PASTE_YOUR_FACTORY_CONTRACT_ADDRESS_HERE";

export const FACTORY_ABI = [
  "function createProject(string name,string symbol,uint256 totalSupply) payable",
  "function launchFee() view returns (uint256)"
];

export async function getFactory() {
  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  return new Contract(FACTORY_ADDRESS, FACTORY_ABI, signer);
}
