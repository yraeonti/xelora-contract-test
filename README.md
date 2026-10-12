🚀 Test Task 🚀

-Modify the existing function that currently uses `onlyOwner` to utilize a `Multiownable` pattern.
-Include in the README an explanation of the rationale and approach for strengthening security protections.

## Explanation

The previous Ownable structure allowed only one owner to carry out privileged actions in the smart contracts. Any attacker who obtains the private key of that owner gets full access to the privileged actions, with no extra security mechanism in place to limit the attacker. The Multiownable implementation removes this single point of failure. It uses a voting system that blocks a privileged action until enough owners approve it. Each owner has one vote, and a function that uses the onlyManyOwners modifier runs only when the number of distinct owners who sent the same call reaches the threshold value. An attacker would therefore need the private keys of at least as many owners as the threshold value to carry out a privileged action. I built this implementation as a simplified version based on the BitClave Multiownable implementation on GitHub.

While this implementation suffices for the test, the industry standard is to use a multisig wallet as the owner and the OpenZeppelin Ownable contract for access control. This removes the need for a custom implementation with custom logic, and it moves the security of the owner to the multisig wallet itself. I used the Multiownable pattern because the task asks for it, and because it makes the approval rule part of the contract code, where anyone can read it on-chain.

I moved the project to a Foundry setup so that I could compile the contracts and run tests against the implementation.
