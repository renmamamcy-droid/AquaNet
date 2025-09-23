
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const deployer = accounts.get("deployer")!;

describe("AquaNet Fishing License Contract Tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("can issue a fishing license", () => {
    const { result } = simnet.callPublicFn(
      "fishing-license",
      "issue-fishing-license",
      [
        Cl.uint(1), // TYPE_COMMERCIAL
        Cl.stringAscii("atlantic-zone-1"),
        Cl.stringAscii("tuna,salmon,cod"),
        Cl.uint(100), // quota limit
        Cl.uint(52560), // 1 year duration
        Cl.stringAscii("no night fishing")
      ],
      address1
    );
    expect(result).toBeOk(Cl.uint(1)); // First license ID
  });

  it("can get license info", () => {
    // First issue a license
    simnet.callPublicFn(
      "fishing-license",
      "issue-fishing-license",
      [
        Cl.uint(2), // TYPE_RECREATIONAL
        Cl.stringAscii("pacific-zone-2"),
        Cl.stringAscii("salmon,trout"),
        Cl.uint(50),
        Cl.uint(26280), // 6 months
        Cl.stringAscii("weekend only")
      ],
      address2
    );

    const { result } = simnet.callReadOnlyFn(
      "fishing-license",
      "get-fishing-license",
      [Cl.uint(2)],
      address2
    );
    
    expect(result).toBeSome();
  });

  it("can check license validity", () => {
    const { result } = simnet.callReadOnlyFn(
      "fishing-license",
      "check-license-validity",
      [Cl.uint(1)],
      address1
    );
    
    expect(result).toBeOk();
  });

  it("can report catch", () => {
    const { result } = simnet.callPublicFn(
      "fishing-license",
      "report-catch",
      [
        Cl.uint(1),
        Cl.uint(10), // catch amount
        Cl.stringAscii("atlantic-waters"),
        Cl.stringAscii("tuna")
      ],
      address1
    );
    
    expect(result).toBeOk(Cl.bool(true));
  });

  it("can get contract stats", () => {
    const { result } = simnet.callReadOnlyFn(
      "fishing-license",
      "get-contract-stats",
      [],
      deployer
    );
    
    // Contract stats returns a tuple directly (not wrapped in ok)
    expect(result).toBeTuple();
  });
});
