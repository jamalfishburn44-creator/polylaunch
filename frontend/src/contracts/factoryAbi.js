export const factoryAbi = [
  {
    type: "function",
    name: "totalProjects",
    stateMutability: "view",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
      },
    ],
  },

  {
    type: "function",
    name: "getProject",
    stateMutability: "view",
    inputs: [
      {
        name: "projectId",
        type: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "id", type: "uint256" },
          { name: "creator", type: "address" },
          { name: "token", type: "address" },
          { name: "name", type: "string" },
          { name: "symbol", type: "string" },
{ name: "metadataURI", type: "string" },
          { name: "totalSupply", type: "uint256" },
          { name: "createdAt", type: "uint256" },
          { name: "active", type: "bool" },
          { name: "reserveUSDC", type: "uint256" },
          { name: "reserveTokens", type: "uint256" },
          { name: "liquidityTokens", type: "uint256" },
          { name: "sold", type: "uint256" },
          { name: "graduated", type: "bool" },
        ],
      },
    ],
  },

  {
  type: "function",
  name: "createProject",
  stateMutability: "nonpayable",
  inputs: [
    {
      name: "name",
      type: "string",
    },
    {
      name: "symbol",
      type: "string",
    },
    {
      name: "metadataURI",
      type: "string",
    },
  ],
  outputs: [],
},

  {
    type: "function",
    name: "buy",
    stateMutability: "nonpayable",
    inputs: [
      {
        name: "projectId",
        type: "uint256",
      },
      {
        name: "amount",
        type: "uint256",
      },
    ],
    outputs: [],
  },

  {
    type: "function",
    name: "sell",
    stateMutability: "nonpayable",
    inputs: [
      {
        name: "projectId",
        type: "uint256",
      },
      {
        name: "amount",
        type: "uint256",
      },
    ],
    outputs: [],
  },

  {
    type: "function",
    name: "getBuyQuote",
    stateMutability: "view",
    inputs: [
      {
        name: "projectId",
        type: "uint256",
      },
      {
        name: "amount",
        type: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
      },
    ],
  },

  {
    type: "function",
    name: "getSellQuote",
    stateMutability: "view",
    inputs: [
      {
        name: "projectId",
        type: "uint256",
      },
      {
        name: "amount",
        type: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
      },
    ],
  },
];
