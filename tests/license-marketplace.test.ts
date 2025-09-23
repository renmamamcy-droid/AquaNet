
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const deployer = accounts.get("deployer")!;

describe("AquaNet License Marketplace Contract Tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("can create a marketplace listing", () => {
    const { result } = simnet.callPublicFn(
      "license-marketplace",
      "create-listing",
      [
        Cl.uint(1), // ASSET-FISHING-LICENSE
        Cl.uint(123), // asset ID
        Cl.stringAscii("Commercial Fishing License"),
        Cl.stringAscii("Valid 1-year commercial fishing license for Atlantic waters"),
        Cl.uint(1000000), // 1 STX price
        Cl.uint(1440), // 10 days duration
        Cl.stringAscii("licenses"),
        Cl.stringAscii("Atlantic Ocean"),
        Cl.stringAscii("excellent")
      ],
      address1
    );
    expect(result).toBeOk(Cl.uint(1)); // First listing ID
  });

  it("can get listing info", () => {
    const { result } = simnet.callReadOnlyFn(
      "license-marketplace",
      "get-listing",
      [Cl.uint(1)],
      address1
    );
    
    expect(result).toBeSome();
  });

  it("can get marketplace stats", () => {
    const { result } = simnet.callReadOnlyFn(
      "license-marketplace",
      "get-marketplace-stats",
      [],
      deployer
    );
    
    // Marketplace stats returns a tuple directly (not wrapped in ok)
    expect(result).toBeTuple();
  });

  it("can calculate marketplace fees", () => {
    const { result } = simnet.callReadOnlyFn(
      "license-marketplace",
      "calculate-fees",
      [Cl.uint(1000000)], // 1 STX
      address1
    );
    
    expect(result).toBeUint(25000); // 2.5% of 1 STX = 0.025 STX
  });

  it("can cancel a listing", () => {
    const { result } = simnet.callPublicFn(
      "license-marketplace",
      "cancel-listing",
      [Cl.uint(1)],
      address1
    );
    
    expect(result).toBeOk(Cl.bool(true));
  });

  it("can update listing price", () => {
    // Create another listing first
    simnet.callPublicFn(
      "license-marketplace",
      "create-listing",
      [
        Cl.uint(2), // ASSET-BOAT-PERMIT
        Cl.uint(456),
        Cl.stringAscii("Boat Permit"),
        Cl.stringAscii("Valid boat permit for coastal waters"),
        Cl.uint(500000), // 0.5 STX
        Cl.uint(720), // 5 days
        Cl.stringAscii("permits"),
        Cl.stringAscii("Pacific Coast"),
        Cl.stringAscii("good")
      ],
      address2
    );

    const { result } = simnet.callPublicFn(
      "license-marketplace",
      "update-listing-price",
      [Cl.uint(2), Cl.uint(750000)], // Update to 0.75 STX
      address2
    );
    
    expect(result).toBeOk(Cl.bool(true));
  });
});
