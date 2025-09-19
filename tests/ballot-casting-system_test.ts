import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Contract info retrieval",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("ballot-casting-system", "get-contract-info", [], deployer.address),
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        
        const result = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(result['total-records'], types.uint(0));
        assertEquals(result['paused'], types.bool(false));
    },
});

Clarinet.test({
    name: "Create and retrieve record",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall(
                "ballot-casting-system", 
                "create-record", 
                [
                    types.buff(Buffer.from("test-hash-data")),
                    types.utf8("Test metadata")
                ], 
                wallet1.address
            ),
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Retrieve the record
        let block2 = chain.mineBlock([
            Tx.contractCall("ballot-casting-system", "get-record", [types.uint(1)], wallet1.address),
        ]);
        
        const record = block2.receipts[0].result.expectSome().expectTuple();
        assertEquals(record['owner'], wallet1.address);
        assertEquals(record['status'], "ACTIVE");
    },
});

Clarinet.test({
    name: "Permission management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        
        // Create record
        let block = chain.mineBlock([
            Tx.contractCall(
                "ballot-casting-system", 
                "create-record", 
                [
                    types.buff(Buffer.from("test-hash-data")),
                    types.utf8("Test metadata")
                ], 
                wallet1.address
            ),
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Grant permission
        let block2 = chain.mineBlock([
            Tx.contractCall(
                "ballot-casting-system", 
                "grant-permission", 
                [
                    types.principal(wallet2.address),
                    types.uint(1),
                    types.uint(64)
                ], 
                wallet1.address
            ),
        ]);
        
        block2.receipts[0].result.expectOk().expectBool(true);
        
        // Check permission
        let block3 = chain.mineBlock([
            Tx.contractCall(
                "ballot-casting-system", 
                "has-permission", 
                [
                    types.principal(wallet2.address),
                    types.uint(1),
                    types.uint(32)
                ], 
                wallet1.address
            ),
        ]);
        
        block3.receipts[0].result.expectBool(true);
    },
});

Clarinet.test({
    name: "Emergency pause functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        
        // Pause contract
        let block = chain.mineBlock([
            Tx.contractCall("ballot-casting-system", "emergency-pause", [], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Try to create record while paused
        let block2 = chain.mineBlock([
            Tx.contractCall(
                "ballot-casting-system", 
                "create-record", 
                [
                    types.buff(Buffer.from("test-hash-data")),
                    types.utf8("Test metadata")
                ], 
                wallet1.address
            ),
        ]);
        
        block2.receipts[0].result.expectErr().expectUint(105);
    },
});
