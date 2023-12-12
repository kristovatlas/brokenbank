# brokenbank
A vulnerable defi dapp challenge for [Gnolang](https://gno.land/)

# Description

`brokenbank` allows users to deposit tokens, withdraw tokens, and transfer them between users. Unfortunately, there are now widespread accusations that the realm dev has rug pulled users. Your colleagues are using blockchain analysis to determine whether theft took place, but your job as a gnolang auditor is to find whether there are any vulnerabilities in the application that would facilitate a theft. View the `bank.gno` and `bank_test.gno` files to look for security issues. The solution is contained in the `solution_test.gno` file.

Functions:
* Deposit() -- deposit funds
* Withdraw() -- withdraw entire balance from bank
* Transfer(from, to, amt)

# Running Tests

`gno test -verbose ./`

Sample output:

```
=== RUN   TestDeposit
--- PASS: TestDeposit (0.00s)
=== RUN   TestUniqueness
--- PASS: TestUniqueness (0.00s)
=== RUN   TestTransferExcess
--- PASS: TestTransferExcess (0.00s)
=== RUN   TestTransferCorrect
--- PASS: TestTransferCorrect (0.00s)
=== RUN   TestWithdrawWithoutDeposit
--- PASS: TestWithdrawWithoutDeposit (0.00s)
=== RUN   TestWithdrawEmpties
--- PASS: TestWithdrawEmpties (0.00s)
=== RUN   TestSolution
--- PASS: TestSolution (0.00s)
ok      ./ 	0.55s
```

# Author

https://twitter.com/kristovatlas

If there is sufficient interest, I will extend this challenge with additions levels. Please contact me via Twitter.
