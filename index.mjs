import { loadStdlib, ask } from "@reach-sh/stdlib";
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib();

const isP1 = await ask.ask(
    `Are you Player 1? (y/n)`,
    ask.yesno
)

const who = isP1 ? 'P1' : 'P2';

console.log(`Play Morra as ${who}`);

let acc = null
const createAcc = await ask.ask(
    `Do you want to create an account? (only possible on devnet)`,
    ask.yesno
)

if (createAcc){
    acc = await stdlib.newTestAccount(stdlib.parseCurrency(1000))
} else {
    const secret = await ask.ask(
        `What is you account secret`,
        (x => x)
    )
    acc = await stdlib.newAccountFromSecret(secret)
}

let ctc = null
if(isP1){
    ctc = acc.deploy(backend);
    ctc.getInfo().then((info) => {
        console.log(`The contract is deployed as = ${JSON.stringify(info)}`)
    })
} else {
    const info = await ask.ask(
        `Pleae paste the contract information`,
        JSON.parse
    )
    ctc = acc.contract(backend, info);
}

const fmt = (x) => stdlib.formatCurrency(x, 4);
const getBalance = async () => fmt(await stdlib.balanceOf(acc));

const before = await getBalance();
console.log(`Your balance is ${before}`);

const interact = { ...stdlib.hasRandom};

interact.informtimeout = ()  => {
    console.log(`You have timed out`);
    ProcessingInstruction.exit(1);
}
    
if(isP1){
    const amt = await ask.ask(
    `How much do you wnat to wager?`,
    stdlib.parseCurrency
    )
    interact.wager = amt;
    interact.deadline = { ETH: 10, ALGO: 1000, CFX: 1000 }[stdlib.connector];
} else {
    interact.acceptWager = async (amt) => {
        const accepted = await ask.ask(
            `Do you accept the wager of ${fmt(amt)}?`,
            ask.yesno
        )
        if (!accepted){
            process.exit(0);
        }
    }
}

const FINGER = [1,2,3,4,5];
const FINGERS = {'1':0, '2':1, '3':2, '4':3, '5':4};
interact.finger = async () => {
    const finger = await ask.ask(`How many finger will you play?`, (x) => {
        const finger = FINGERS[x];
        if (finger === undefined){
            throw Error(`Not a valid finger ${finger}`)
        }
        return finger;
    })
    console.log(`You played ${FINGER[finger]} fingers`);
    return finger;
}
interact.guess = async (finger) => {
    const guess = await ask.ask(`How many finger will you opponent play?`, (x) => {
        const guess = FINGERS[x];
        if (guess === undefined){
            throw Error(`Not a valid guess ${guess}`)
        }
        return guess;
    })
    console.log(`You guess is ${parseInt(FINGER[guess]) + parseInt(finger) + 1} fingers`);
    return guess;
}

const RESULT = ['Draw', 'P1 Wins', 'P2 Wins'];
interact.seeResult =  async (result) => {
    console.log(`The result is ${RESULT[result]}`);
}

const part = isP1 ? ctc.p.P1 : ctc.p.P2;
await part(interact);

const after = await getBalance();
console.log(`Your balance is ${after}`);

ask.done();