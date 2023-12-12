package bank

import (
	"std"
	"fmt" // for logging at debug level
)

type BalanceTuple struct {
	userid uint64
	addr std.Address
	value uint64
}

const DebugPrint = false

func dprint(str string) {
	if DebugPrint {
		println("DEBUG: ", str)
	}
}

// Keeps track of users balances
var Balances []BalanceTuple

// Initializes balance if address not registered. Returns index of the record if address was
// previously registered, or -1 if not previously registered.
func initBalance(addr std.Address, amt uint64) int64 {
	found := false
	// For efficiency, start with most recent records
	for i := len(Balances) - 1; i > 0; i-- {
		if Balances[i].addr == addr {
			return int64(i)
		}
	}

	newUserId := uint64(len(Balances))
	record := BalanceTuple{newUserId, addr, amt}
	Balances = append(Balances, record)
	return int64(-1)
}

func Deposit() {
	caller := std.GetOrigCaller()
	dprint(fmt.Sprintf("Deposit(): originall caller = %v", caller))

	sentCoins := std.GetOrigSend()

	if len(sentCoins) != 1 {
		panic(fmt.Sprintf("Send only one type of coin: %v", sentCoins))
	}
	sentAmount := uint64(sentCoins[0].Amount) 

	dprint(fmt.Sprintf("Deposit(): sentAmount = %v", sentAmount))

	registeredIndex := initBalance(caller, sentAmount) 

	dprint(fmt.Sprintf("Deposit(): registeredIndex = %v", registeredIndex))

	if registeredIndex != -1 {
		// Add to existing balance
		oldBalance := Balances[registeredIndex].value
		newBalance := oldBalance + sentAmount
		Balances[registeredIndex].value = newBalance
	}
}

// Withdraw all funds for given user
// If user is not registered, no send action will be initiated
// Returns: Whether user was previously registered
func Withdraw(to std.Address) bool {

	caller := std.GetOrigCaller()
	registeredIndex := initBalance(caller, 0)

	if registeredIndex != -1 {
		for i := 0; i < len(Balances); i++ {
			if Balances[i].addr == caller {
				banker := std.GetBanker(std.BankerTypeRealmSend)
				pkgAddr := std.GetOrigPkgAddr()

				banker.SendCoins(pkgAddr, caller, std.Coins{{"ugnot", int64(Balances[i].value)}})

				Balances[i].value = 0
			}
		}
		return true
	} else {
		return false
	}
}

func Transfer(to std.Address, amt uint64) {
	caller := std.GetOrigCaller()

	if caller == to {
		panic("Caller cannot transfer to self.")
	}

	//verify caller has enough funds to transfer
	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == caller {
			if Balances[i].value < amt {
				panic("Caller has insufficient funds to transfer.")
			}
		}
	}

	// Initialize recipient to 0 balance if not yet registered
	initBalance(to, 0)

	for i := 0; i < len(Balances); i++ {
		if Balances[i].addr == to {
			dprint(fmt.Sprintf("Transfer(): Recipient old balance at [%v]: %v", i, Balances[i].value))
			// Set new balance for recipient
			Balances[i].value = Balances[i].value + amt

			dprint(fmt.Sprintf("Transfer(): Recipient new balance at [%v]: %v", i, Balances[i].value))

		} else if Balances[i].addr == caller {
			// Deduct from sender
			Balances[i].value = Balances[i].value - amt
		}
	}
}
