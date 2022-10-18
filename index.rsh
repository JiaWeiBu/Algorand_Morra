'reach 0.1'

const [ finger, fONE, fTWO, fTHREE, fFOUR, fFIVE ] = makeEnum(5)
const [ guess, gONE, gTWO, gTHREE, gFOUR, gFIVE ] = makeEnum(5)
const [ isResult, DRAW, P1_WIN, P2_WIN ] = makeEnum(3)

const winner = (fingerP1, fingerP2, guessP1, guessP2) => 
    ((guessP1 == fingerP2 && guessP2 == fingerP1) ? 0 :
    guessP1 == fingerP2 ? 1 :
    guessP2 == fingerP1 ? 2 :
    0)

assert(winner(fONE, fONE, gONE, gTWO) === P1_WIN)
assert(winner(fONE, fONE, gTWO, gONE) === P2_WIN)
assert(winner(fONE, fONE, gONE, gONE) === DRAW)

forall(UInt, fingerP1 =>
    forall(UInt, fingerP2 =>
        forall(UInt, guessP1 =>
            forall(UInt, guessP2 =>
                assert(isResult(winner(fingerP1, fingerP2, guessP1, guessP2)))))))

const Player = {
    ...hasRandom,
    finger: Fun([], UInt),
    guess: Fun([UInt], UInt),
    seeResult: Fun([UInt], Null),
    informTimeout: Fun([], Null),
}

export const main = Reach.App(() => {
    const P1 = Participant('P1', {
        ...Player,
        wager: UInt,
        deadline: UInt,
    })
    const P2 = Participant('P2', {
        ...Player,
        acceptWager: Fun([UInt], Null),
    })  
    init()

    const informTimeout = () => {
        each([P1, P2], () => {
            interact.informTimeout()
        })
    }

    P1.only(() => {
        const amount = declassify(interact.wager)
        const deadline = declassify(interact.deadline)
    })
    P1.publish(amount, deadline)
        .pay(amount)
    commit()

    P2.only(() => {
        interact.acceptWager(amount)
    })
    P2.pay(amount)
        .timeout(relativeTime(deadline), () => closeTo(P1, informTimeout))

    var result = DRAW
    invariant(balance() == 2 * amount && isResult(result))
    while(result == DRAW){
        commit()

        P1.only(() => {
            const _fingerP1 = interact.finger()
            const getFinger = declassify(_fingerP1)
            const _guessP1 = interact.guess(getFinger)
            const [_commitFingerP1, _saltFingerP1] = makeCommitment(interact, _fingerP1)
            const [_commitGuessP1, _saltGuessP1] = makeCommitment(interact, _guessP1)
            const commitFingerP1 = declassify(_commitFingerP1)
            const commitGuessP1 = declassify(_commitGuessP1)
        })
        P1.publish(commitFingerP1, commitGuessP1)
            .timeout(relativeTime(deadline), () => closeTo(P2, informTimeout))
        commit()

        unknowable(P2, P1(_fingerP1, _saltFingerP1, _guessP1, _saltGuessP1, getFinger))
        P2.only(() => {
            const fingerP2 = declassify(interact.finger())
            const guessP2 = declassify(interact.guess(fingerP2))
        })
        P2.publish(fingerP2, guessP2)
            .timeout(relativeTime(deadline), () => closeTo(P1, informTimeout))
        commit()

        P1.only(() => {
            const saltFingerP1 = declassify(_saltFingerP1)
            const fingerP1 = declassify(_fingerP1)
            const saltGuessP1 = declassify(_saltGuessP1)
            const guessP1 = declassify(_guessP1)
        })
        P1.publish(saltFingerP1, fingerP1, saltGuessP1, guessP1)
            .timeout(relativeTime(deadline), () => closeTo(P2, informTimeout))
        checkCommitment(commitFingerP1, saltFingerP1, fingerP1)
        checkCommitment(commitGuessP1, saltGuessP1, guessP1)
        
        result = winner(fingerP1, fingerP2, guessP1, guessP2)
        continue
    }
    
    assert(result == P1_WIN || result == P2_WIN)
    transfer(2*amount).to(result == P1_WIN ? P1 : P2)
    commit()

    each([P1,P2], () => {
        interact.seeResult(result)
    })
})