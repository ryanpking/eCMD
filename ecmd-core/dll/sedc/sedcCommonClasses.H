//IBM_PROLOG_BEGIN_TAG
/* 
 * Copyright 2003,2016 IBM International Business Machines Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * 	http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
//IBM_PROLOG_END_TAG

#ifndef sedcCommonClasses_h
#define sedcCommonClasses_h

// Class Description *************************************************
//                                                                      
//  Name:  sedcCommonClasses
//  Base class: 
//
//  Description: 
//  Usage:
//
// End Class Description *********************************************

//--------------------------------------------------------------------
// Includes
//--------------------------------------------------------------------
#include <list>
#include <string>
#include <vector>
#include <inttypes.h>


//--------------------------------------------------------------------
//  Forward References                                                
//--------------------------------------------------------------------

class sedcLatchLine
{
   public:
     // Constructors
     inline sedcLatchLine():
     state(0x0),
     offsetJTAG(-1),
     offsetFSI(-1),
     lhsNum(-1),
     rhsNum(-1),
     direction(-1),
     hashKey(0x0),
     holderID(99)
     {}; /*uninitialized member*/
     //@01a Tell Beam to ignore uninitialized error with comment above.

     // Destructor
     virtual inline ~sedcLatchLine() {};


     // Operators
     sedcLatchLine& operator=(const sedcLatchLine &rhs);  ///< Used for copy
     sedcLatchLine(const sedcLatchLine &rhs);  ///< Used for copy
     int operator<(const sedcLatchLine &rhs) const; ///< Required for STL sort

     /* Other functions */
     void reset(); ///< Resets all the variables to they state they were in the constructor

     void setName(std::string newLatchName); ///< Sets the name field equal to new name, and gens the hashKey


  public:  // Data
    uint32_t state;      ///< Contains information about what states are on (clock-on, etc..) and special operators   (!, etc..)
    int length;     ///< Length of the data to fetch
    int offsetJTAG; ///< Offset into the chip ring from the JTAG column
    int offsetFSI;  ///< Offset into the chip ring from the FSI column
    int lhsNum;     ///< left hand side Number - Value x of an (x:y) entry
    int rhsNum;     ///< right hand side Number - Value y of an (x:y) entry
    int direction;  ///< 1 if data in normal order (3:5), 0 if singlebit, -1 if data in reverse (5:3)
    std::string   latchName;   ///< The latch being worked on out of the scandef/scomdef
    std::string   latchExtras; ///< Contains the ()'s as well as any comments on the line
    std::string   comment;     ///< Contains any comment that was on the line
    uint64_t  hashKey;     ///< A hashKey generated off the latchName, used for look ups.
    uint32_t  holderID;     ///< It's location in the spylines once built - only used in edc mode

  private:  // functions

  private:  // Data

};

/**
 * @brief Return structure from our specialized tokenizer
 */
class sedcFileLine
{
   public:
     // Constructors
     inline sedcFileLine() {};

     // Destructor
     virtual inline ~sedcFileLine() {};

     // Operators
     sedcFileLine& operator=(const sedcFileLine &rhs);  ///< Used for copy
     sedcFileLine(const sedcFileLine &rhs);  ///< Used for copy

     /* Other functions */
     void reset(); ///< Resets all the variables to they state they were in the constructor

  public:  // Data
    std::string                   realLine;       ///< The line as it was read from the file
    std::vector<std::string>      tokens;         ///< The line after it's been turned into tokens
    std::string                   comment;        ///< If a comment was on the line, it's moved here.  Not included in the token list

  private:  // functions

  private:  // Data

};

/**
 * @brief Hold in the info necessary to read/write the filepos to the spy hash file
 */
struct sedcHash32Entry {
  uint32_t key;             ///< 32 bit hash key generated off the spy name
  uint32_t filepos;         ///< Position in the spy file where this spy is at
  int operator<(const sedcHash32Entry &rhs) const { return (key<rhs.key); }  ///< Used for sorts
};

struct sedcHash64Entry {
  uint64_t key;             ///< 64 bit hash key generated off the spy name
  uint32_t filepos;         ///< Position in the spy file where this spy is at
  int operator<(const sedcHash64Entry &rhs) const { return (key<rhs.key); }  ///< Used for sorts
};

/**
 * @brief return type from sedcStringToClkState() function
 */

typedef enum
{
   SEDC_CLK_UNKNOWN = 0,
   SEDC_CLK_STOP,
   SEDC_CLK_RUNNING,
   SEDC_CLK_INDEPENDENT,
   SEDC_CLK_INVALID
} sedcClockState;

#endif /* sedcCommonClasses_h */
