// Max size of inputs
// global encodN: u32 = 100;
// global charN: u32 = 100;
// global lenN: u32 = 10;
// global lenN: u32 = 10;
// global maxLenOfLen: u32 = 5;
// global maxRecDepth: u32 = 5;
global encodN: u32 = 10;
global charN: u32 = 10;
global strLen: u32 = 10;
global lenN: u32 = 5;
global maxLenOfLen: u32 = 3;
global maxRecDepth: u32 = 3;


fn rec_iter(
    encodArray:[u32;encodN],
    mut charArray:[u32;charN],
    mut lenArray:[u32;lenN],
    mut depArray:[u32;lenN],
    maxLen:u32
) -> ([u32;charN],[u32;lenN],[u32;lenN],u32,u32) {

    let mut encodIndex:u32 = 0;
    let mut charIndex:u32 = 0;
    let mut depthIndex:u32 = 0;
    let mut depth:u32 = 1;//initial depth assumed 1 in input

    // Manual recursion stack
    let mut stackEnd:[u32;maxRecDepth] = [0;maxRecDepth];
    let mut stackDepth:[u32;maxRecDepth] = [0;maxRecDepth];
    let mut stackPtr:u32 = 0;

    // Fully bounded loop (important for Noir)
    for _ in 0..encodN {

        if encodIndex >= maxLen {
            // If inside a list, pop stack
            if stackPtr > 0 {
                let top = stackPtr - 1;
                if encodIndex == stackEnd[top] {
                    depth = stackDepth[top];
                    stackPtr -= 1;
                }
            }
        } else {
            assert(encodIndex < maxLen);
            let prefix = encodArray[encodIndex];

            // ---------------- SINGLE BYTE ----------------
            if prefix >= 0 {
                if prefix <= 127 {
                    assert(charIndex < charN);
                    assert(depthIndex < lenN);
                    assert(depthIndex < lenN);

                    charArray[charIndex] = prefix;
                    lenArray[depthIndex] = 1;
                    depArray[depthIndex] = depth;

                    charIndex += 1;
                    depthIndex += 1;
                    encodIndex += 1;
                }

                // ---------------- SHORT STRING ----------------
                else if prefix <= 183 {

                    let strLen = prefix - 128;

                    assert(encodIndex + 1 + strLen <= maxLen);
                    assert(charIndex + strLen <= charN);
                    assert(depthIndex < lenN);
                    assert(depthIndex < lenN);

                    lenArray[depthIndex] = strLen;
                    depArray[depthIndex] = depth;

                    for i in 0..charN {
                        if i < strLen {
                            let b = encodArray[encodIndex + 1 + i];
                            // ---- STRICT CHECK: no list inside string ----
                            assert(b <= 127);
                            assert(b>0);
                            charArray[charIndex + i] = b;
                        }
                    }

                    charIndex += strLen;
                    depthIndex += 1;
                    encodIndex += 1 + strLen;
                }

                // ---------------- LONG STRING ----------------
                else if prefix <= 191 {

                    let len_of_len = prefix - 183;
                    let mut actLen:u32 = 0;

                    for i in 0..maxLenOfLen {
                        if i < len_of_len {
                            actLen =
                            actLen * 256 +
                            encodArray[encodIndex + 1 + i];
                        }
                    }

                    assert(len_of_len <= maxLenOfLen);
                    assert(encodIndex + 1 + len_of_len <= maxLen);
                    assert(encodIndex + 1 + len_of_len + actLen <= maxLen);
                    assert(charIndex + actLen <= charN);
                    assert(depthIndex < lenN);
                    assert(depthIndex < lenN);


                    lenArray[depthIndex] = actLen;
                    depArray[depthIndex] = depth;

                    for i in 0..charN {
                        if i < actLen {
                            let b = encodArray[encodIndex + 1 + len_of_len + i];

                            // ---- STRICT CHECK ----
                            assert(b <= 127);

                            charArray[charIndex + i] = b;
                        }
                    }

                    charIndex += actLen;
                    depthIndex += 1;
                    encodIndex += 1 + len_of_len + actLen;
                }

                // ---------------- SHORT LIST ----------------
                else if prefix <= 247 {
                    let list_len = prefix - 192;

                    assert(stackPtr < maxRecDepth);
                    assert(encodIndex + 1 + list_len <= maxLen);

                    // -------- EMPTY LIST --------
                    if list_len == 0 {
                        lenArray[depthIndex] = 0;
                        depArray[depthIndex] = depth;
                        depthIndex += 1;

                        encodIndex += 1;
                    } else {
                        // Normal short list
                        stackEnd[stackPtr] = encodIndex + 1 + list_len;
                        stackDepth[stackPtr] = depth;
                        stackPtr += 1;
                        depth += 1;
                        encodIndex += 1;
                    }
                }

                // ---------------- LONG LIST ----------------
                else if prefix <= 255 {

                    let len_of_len = prefix - 247;
                    let mut actLen:u32 = 0;

                    for i in 0..maxLenOfLen {
                        if i < len_of_len {
                            actLen = actLen * 256 + encodArray[encodIndex + 1 + i];
                        }
                    }

                    assert(actLen <= charN);
                    assert(len_of_len <= maxLenOfLen);
                    assert(encodIndex + 1 + len_of_len <= maxLen);
                    assert(encodIndex + 1 + len_of_len + actLen <= maxLen);
                    assert(stackPtr < maxRecDepth);

                    // -------- EMPTY LIST --------
                    if actLen == 0 {
                        lenArray[depthIndex] = 0;
                        depArray[depthIndex] = depth;
                        depthIndex += 1;

                        encodIndex += 1 + len_of_len;
                    } else {
                        // Normal long list
                        stackEnd[stackPtr] =
                            encodIndex + 1 + len_of_len + actLen;
                        stackDepth[stackPtr] = depth;
                        stackPtr += 1;

                        depth += 1;
                        encodIndex += 1 + len_of_len;
                    }
                } else {
                    // Invalid RLP prefix
                    assert(false);
                }
            } else {
                // Invalid RLP prefix
                assert(false);
            }
            // ---------------- CHECK IF WE FINISHED A LIST ----------------
            if stackPtr > 0 {
                let top = stackPtr - 1;

                if encodIndex == stackEnd[top] {
                    depth = stackDepth[top];
                    stackPtr -= 1;
                }
            }
        }
    }

    assert(encodIndex == maxLen);
    assert(stackPtr == 0);

    (charArray,lenArray,depArray,charIndex,depthIndex)
}

fn main(
    encodIp: [u32; encodN],
    op: str<strLen>,
    maxLen: u32
) {
    // ---------------- Convert op string ----------------
    let bytes = op.as_bytes();
    let mut charIp: [u32; charN] = [0; charN];
    let mut lenIp: [u32; lenN] = [0; lenN];
    let mut depIp: [u32; lenN] = [0; lenN];
    let mut depth: u32 = 0;
    let mut charInd: u32 = 0;
    let mut lenInd: u32 = 0;
    let mut l: u32 = 0;

    for i in 0..strLen {
        if i < bytes.len() {
            let b: u32 = bytes[i] as u32;
            // ---------------- SPACE ----------------
            if b == 32 {
                // ignore
            }
            // ---------------- '[' ----------------
            else if b == 91 {
                depth += 1;
                l = 0;
            }
            // ---------------- ',' ----------------
            else if b == 44 {
                if l > 0 {
                    // bounds safety
                    assert(lenInd <= lenN);
                    lenIp[lenInd] = l;
                    depIp[lenInd] = depth;
                    lenInd += 1;
                    l = 0;
                }
            }
            // ---------------- ']' ----------------
            else if b == 93 {
                // depth must be valid
                assert(depth > 0);
                if l > 0 {
                    // normal element
                    assert(lenInd < lenN);
                    lenIp[lenInd] = l;
                    depIp[lenInd] = depth;
                    lenInd += 1;
                    l = 0;
                } else {
                    // empty list case
                    assert(lenInd < lenN);
                    assert(charInd < charN);
                    charIp[charInd] = 0; // placeholder for empty list
                    charInd += 1;
                    lenIp[lenInd] = 0;
                    depIp[lenInd] = depth;
                    lenInd += 1;
                }
                depth -= 1;
            }
            // ---------------- CHARACTER ----------------
            else {
                // char array bounds safety
                assert(charInd < charN);
                charIp[charInd] = b;
                charInd += 1;
                l += 1;
            }
        }
    }
    // Final structural safety
    assert(depth == 0);        // all brackets closed
    assert(charInd <= charN);
    assert(lenInd <= lenN);

    // ---------------- Now run your decoder ----------------
    let mut encodArray: [u32; encodN] = [0; encodN];
    for i in 0..encodN {
        encodArray[i] = encodIp[i];
    }

    let mut charArray: [u32; charN] = [0; charN];
    let mut lenArray: [u32; lenN] = [0; lenN];
    let mut depArray: [u32; lenN] = [0; lenN];

    let (charArray, lenArray, depArray, NewCharInd, NewDepInd) =
        rec_iter(encodArray, charArray, lenArray, depArray, maxLen);

    // ---------------- BASIC SIZE CHECKS ----------------
    assert(maxLen > 0);
    assert(maxLen <= encodN);
    assert(NewCharInd <= charN);
    assert(NewDepInd <= lenN);
    assert(NewDepInd <= lenN);
    // Compare charArray with charIp
    for i in 0..charN {
        assert(charArray[i] == charIp[i]);
    }

    // Compare lenArray with lenIp
    for i in 0..lenN {
        assert(lenArray[i] == lenIp[i]);
    }

    // Compare depArray with depIp
    for i in 0..lenN {
        assert(depArray[i] == depIp[i]);
    }
}

// fn main(encodIp:[u32;encodN],charIp:[u32;charN],lenIp:[u32;lenN],depIp:[u32;lenN],maxLen:u32) {
//     //encoded input in decimal form
//     let mut encodArray: [u32;encodN] = [0;encodN];
//     for i in 0..encodN {
//         //encodArray[i] = (encodIp[i]/10)*16+(encodIp[i]%10);
//         encodArray[i] = encodIp[i];
//     }
//     //charArray,lenArray,depArray to compare with the charIp,lenIp,depIp
//     let mut charArray: [u32;charN] = [0;charN];
//     let mut lenArray: [u32;lenN] = [0;lenN];
//     let mut depArray: [u32;lenN] = [0;lenN];
//     let (charArray,lenArray,depArray,NewCharInd,NewDepInd) =
//         rec_iter(encodArray,charArray,lenArray,depArray,maxLen);

//     // ---------------- BASIC SIZE CHECKS ----------------
//     assert(maxLen > 0);
//     assert(maxLen <= encodN);
//     assert(NewCharInd <= charN);
//     assert(NewDepInd <= lenN);
//     assert(NewDepInd <= lenN);
//     // Compare charArray with charIp
//     for i in 0..charN {
//         assert(charArray[i] == charIp[i]);
//     }

//     // Compare lenArray with lenIp
//     for i in 0..lenN {
//         assert(lenArray[i] == lenIp[i]);
//     }

//     // Compare depArray with depIp
//     for i in 0..lenN {
//         assert(depArray[i] == depIp[i]);
//     }
// }