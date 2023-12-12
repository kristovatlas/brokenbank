// language: go

// To compile the package and run the tests, we can run the following 
// command from the directory containing this file:
// gno test -verbose ./

/* Useful testing functions utilized in this test suite:
 * SendCoins(from, to Address, amt Coins)
 * std.TestIssueCoins(addr, coins): issues test coins to designated addr
 * std.TestSetOrigCaller: Sets the caller of a function call to realm to spoof value returned in 
 * 	 realm by std.GetOrigCaller()
 * std.TestSetOrigSend
 * std.TestSetOrigPkgAddr
 */

package bank

import (
	"std"
	"testing"
)

const BankTestAmt = 1000000

/********************
 * HELPER FUNCTIONS *
 ********************/

//Get on-chain balance
func getBalance(addr std.Address) int64 {
	bankerRead := std.GetBanker(std.BankerTypeReadonly)
	coins := bankerRead.GetCoins(addr)
	amt := int64(0)
	if len(coins) > 0 {
		amt = coins[0].Amount
	}
	return amt
}

//Print on-chain balance of address
func printBalance(label string, addr std.Address) {
	amt := getBalance(addr)
	println(label, " balance: ", amt)
}

//Simulates sending funds from one address to another
func simulateSend(from std.Address, to std.Address, amt uint64) {
	// Hack: Set the sender as package addr temporarily to make SendCoins happy
	prevPkgAddr := std.GetOrigPkgAddr()
	std.TestSetOrigPkgAddr(from)

	std.TestSetOrigSend(std.Coins{{"ugnot", int64(amt)}}, nil)
	bankerSend := std.GetBanker(std.BankerTypeRealmSend)
	bankerSend.SendCoins(from, to, std.Coins{{"ugnot", int64(amt)}})

	std.TestSetOrigPkgAddr(prevPkgAddr)
}

/*********
 * TESTS *
 *********/

 // General test for the functionality of Deposit()
func TestDeposit(t *testing.T) {
	Balances = Balances[:0] // Ensure balances are fresh for test

	aliceAddr := std.DerivePkgAddr("brokenbank.TestDeposit.alice")
	//println("DEBUG: Alice's address: ", aliceAddr)

	//printBalance("Alice starting balance on-chain before issuance", aliceAddr)

	// use mock address as caller
	std.TestSetOrigCaller(aliceAddr)
	
	pkgAddr := std.GetOrigPkgAddr()
	startRealmBal := getBalance(pkgAddr)
	//println("DEBUG: Realm address: ", pkgAddr)

	//printBalance("Realm starting balance on-chain", pkgAddr)

	// Issue test coins to Alice
	std.TestIssueCoins(aliceAddr, std.Coins{{"ugnot", BankTestAmt}})

	//printBalance("Alice starting balance on-chain", aliceAddr)

	simulateSend(aliceAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(aliceAddr)
	Deposit()

	//printBalance("Alice on-chain balance after sending", aliceAddr)
	//printBalance("Realm on-chain balance after sending", pkgAddr)

	//Check on-chain balances

	if getBalance(aliceAddr) != 0 {
		t.Fatal("Failed to deposit all of Alice's funds to bank. Alice balance: " , getBalance(aliceAddr))
	}
	if getBalance(pkgAddr) != startRealmBal + BankTestAmt {
		t.Fatal("Incorrect on-chain balance for realm after deposit.")
	}

	// Check Alice's bank balance
	foundAlice := false
	aliceBankBalance := int64(-1)
	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == aliceAddr {
			//println("Alice bank balance after Deposit(): ", Balances[i].value)
			foundAlice = true
			aliceBankBalance = int64(Balances[i].value)
		}
	}
	if !foundAlice {
		t.Fatal("Unable to locate Alice bank balance after deposit.")
	}
	if aliceBankBalance != BankTestAmt {
		t.Fatal("Alice bank balance after deposit is incorrect.")
	}
}

// This test verifies that a given address can only be listed once in Balances as enforced by
// the initBalance() function.
func TestUniqueness(t *testing.T) {
	Balances = Balances[:0] // Ensure balances are fresh for test
	
	adminAddr := std.DerivePkgAddr("brokenbank.TestUniqueness.admin")
	aliceAddr := std.DerivePkgAddr("brokenbank.TestUniqueness.alice")

	pkgAddr := std.GetOrigPkgAddr()
	//std.TestSetOrigPkgAddr(pkgAddr)

	bankerSend := std.GetBanker(std.BankerTypeRealmSend)
	
	// Admin is realm developer, by convention performs first deposit to bank
	std.TestIssueCoins(adminAddr, std.Coins{{"ugnot", BankTestAmt}})
	simulateSend(adminAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(adminAddr)
	Deposit()

	// Initialize Alice's on-chain balance
	std.TestIssueCoins(aliceAddr, std.Coins{{"ugnot", BankTestAmt * 2}})

	// send coins from Alice to bank twice
	std.TestSetOrigCaller(aliceAddr)
	for i := 0; i <= 1; i++ {
		simulateSend(aliceAddr, pkgAddr, BankTestAmt)
		Deposit()
	}

	// INVARIANT: Users should be listed only once in balances regardless of how many times 
	// bank functions are called.
	aliceCount := 0
	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == aliceAddr {
			aliceCount += 1
		}
	}

	if aliceCount != 1 {
		t.Fatal("Alice address in balances zero or more than once: ", aliceCount)
	}
}

// Verify you can't transfer more than current bank balance
func TestTransferExcess(t *testing.T) {
	Balances = Balances[:0] // Ensure balances are fresh for test

	// Alice => Bob
	adminAddr := std.DerivePkgAddr("brokenbank.TestUniqueness.admin")
	aliceAddr := std.DerivePkgAddr("brokenbank.TestTransferExcess.alice")
	bobAddr := std.DerivePkgAddr("brokenbank.TestTransferExcess.bob")

	pkgAddr := std.GetOrigPkgAddr()

	// Admin is realm developer, by convention performs first deposit to bank
	std.TestIssueCoins(adminAddr, std.Coins{{"ugnot", BankTestAmt}})
	simulateSend(adminAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(adminAddr)
	Deposit()

	// Initialize Alice's on-chain balance
	std.TestIssueCoins(aliceAddr, std.Coins{{"ugnot", BankTestAmt}})

	// Simulate deposit
	simulateSend(aliceAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(aliceAddr)
	Deposit()

	defer func() {
		if r := recover(); r == nil {
			// No panic occurred, raise an error
			t.Error("Expected panic due to excessive Transfer amt, but none occurred")
		}
		// If a panic occurred, do nothing (test passes)
	}()

	// Call the function that should panic
	Transfer(bobAddr, BankTestAmt * 2) // amt * 2 exceeds balance
}

// Verify the correct amount is transferred
func TestTransferCorrect(t *testing.T) {
	Balances = Balances[:0] // Ensure balances are fresh for test

	adminAddr := std.DerivePkgAddr("brokenbank.TestUniqueness.admin")
	aliceAddr := std.DerivePkgAddr("brokenbank.TestTransferCorrect.alice")
	bobAddr := std.DerivePkgAddr("brokenbank.TestTransferCorrect.bob")

	pkgAddr := std.GetOrigPkgAddr()

	// Admin is realm developer, by convention performs first deposit to bank
	std.TestIssueCoins(adminAddr, std.Coins{{"ugnot", BankTestAmt}})
	simulateSend(adminAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(adminAddr)
	Deposit()

	// Initialize Alice's on-chain balance
	std.TestIssueCoins(aliceAddr, std.Coins{{"ugnot", BankTestAmt * 2}})

	// Simulate deposit
	simulateSend(aliceAddr, pkgAddr, BankTestAmt * 2)
	std.TestSetOrigCaller(aliceAddr)
	Deposit()

	bankStartBalance := getBalance(pkgAddr)

	Transfer(bobAddr, BankTestAmt) // Alice => Bob quanity:BankTestAmt

	//INVARIANT: Verify bank still has correct amount after transfer
	if getBalance(pkgAddr) != bankStartBalance {
		t.Fatal("Bank balance changed as a result of Transfer().")
	}

	//Ensure bank balances are correct
	aliceBalance := -1
	bobBalance := -1
	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == aliceAddr {
			aliceBalance = int(Balances[i].value)
		} else if Balances[i].addr == bobAddr {
			bobBalance = int(Balances[i].value)
		}
	}
	if aliceBalance != BankTestAmt {
		t.Fatal("Final Alice bank balance incorrect: ", aliceBalance)
	}
	if bobBalance != BankTestAmt {
		t.Fatal("Final Bob bank balance incorrect: ", bobBalance)
	}
}

// Verify that calling withdraw without first depositing results in no funds sent	
func TestWithdrawWithoutDeposit(t *testing.T) {
	Balances = Balances[:0] // Ensure balances are fresh for test
	
	adminAddr := std.DerivePkgAddr("brokenbank.TestUniqueness.admin")
	aliceAddr := std.DerivePkgAddr("brokenbank.TestWithdrawWithoutDeposit.alice")
	std.TestSetOrigCaller(aliceAddr)
	pkgAddr := std.GetOrigPkgAddr()

	// Admin is realm developer, by convention performs first deposit to bank
	std.TestIssueCoins(adminAddr, std.Coins{{"ugnot", BankTestAmt}})
	simulateSend(adminAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(adminAddr)
	Deposit()

	std.TestSetOrigCaller(aliceAddr)
	Withdraw(aliceAddr)

	if getBalance(aliceAddr) != 0 {
		t.Fatal("Alice should have 0 coins on-chain after calling empty withdraw.")
	}

	// Alice should now have a single 0 bank balance
	aliceCount := 0
	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == aliceAddr {
			aliceCount++
			if Balances[i].value != 0 {
				t.Fatal("Alice's bank balance is not zero.")
			}
		}
	}
	if aliceCount != 1 {
		t.Fatal("Alice appears wrong number of times in balances.")
	}
}

// Verify that calling withdraw empties the balance
func TestWithdrawEmpties(t *testing.T) {
	Balances = Balances[:0] // Ensure balances are fresh for test
	
	adminAddr := std.DerivePkgAddr("brokenbank.TestUniqueness.admin")
	aliceAddr := std.DerivePkgAddr("brokenbank.TestWithdrawEmpties.alice")
	pkgAddr := std.GetOrigPkgAddr()

	// Admin is realm developer, by convention performs first deposit to bank
	std.TestIssueCoins(adminAddr, std.Coins{{"ugnot", BankTestAmt}})
	simulateSend(adminAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(adminAddr)
	Deposit()

	// Initialize Alice's on-chain balance
	std.TestIssueCoins(aliceAddr, std.Coins{{"ugnot", BankTestAmt}})

	if getBalance(aliceAddr) != BankTestAmt {
		t.Fatal("Alice starting on-chain balance is incorrect.")
	}

	// Simulate deposit
	simulateSend(aliceAddr, pkgAddr, BankTestAmt)
	std.TestSetOrigCaller(aliceAddr)
	Deposit()

	if getBalance(aliceAddr) != 0 {
		t.Fatal("Alice starting on-chain balance after deposit is incorrect.")
	}

	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == aliceAddr {
			if Balances[i].value != BankTestAmt {
				t.Fatal("Alice bank balance after Deposit is incorrect.")
			}
		}
	}

	std.TestSetOrigCaller(aliceAddr)
	wasAliceRegistered := Withdraw(aliceAddr)

	if !wasAliceRegistered {
		t.Fatal("Alice should have been registered with the bank.")
	}

	aliceBalAfterWithdraw := getBalance(aliceAddr)

	if aliceBalAfterWithdraw != BankTestAmt {
		t.Fatal("Alice on-chain balance after first withdraw is incorrect: ", aliceBalAfterWithdraw)
	}
	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == aliceAddr {
			if Balances[i].value != 0 {
				t.Fatal("Alice bank balance after first withdraw is incorrect.")
			}
		}
	}

	bankStartBalance := getBalance(pkgAddr)
	
	//Attempt withdraw when alice has 0 balance
	std.TestSetOrigCaller(aliceAddr)
	Withdraw(aliceAddr)

	if getBalance(pkgAddr) != bankStartBalance {
		t.Fatal("Bank balance has changed after second withdraw attempt.")
	}

	if getBalance(aliceAddr) != BankTestAmt {
		t.Fatal("Alice on-chain balance after second withdraw is incorrect.")
	}
	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == aliceAddr {
			if Balances[i].value != 0 {
				t.Fatal("Alice bank balance after second withdraw is incorrect.")
			}
		}
	}
}
