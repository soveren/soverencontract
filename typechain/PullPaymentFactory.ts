/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer } from "ethers";
import { Provider } from "@ethersproject/providers";

import type { PullPayment } from "./PullPayment";

export class PullPaymentFactory {
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): PullPayment {
    return new Contract(address, _abi, signerOrProvider) as PullPayment;
  }
}

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "dest",
        type: "address",
      },
    ],
    name: "payments",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address payable",
        name: "payee",
        type: "address",
      },
    ],
    name: "withdrawPayments",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];
