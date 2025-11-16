module series_1
//https://www.rascal-mpl.org/docs/library/lang/java/m3/ast/
import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import List;
import Set;
import String;

import analysis::graphs::Graph;
import Set;
import Relation;

int main() {
    loc smallsql_loc = |project://smallsql0.21_src/|;
    loc hsql_loc = |project://hsqldb-2.3.1/|;
    println("SmallSQL:");
    printAllMetrics(smallsql_loc);
    println("HSQL:");
    printAllMetrics(hsql_loc);

    return 0;
}

// main sequence code
void printAllMetrics(loc project_loc){
    list[Declaration] asts = getASTs(project_loc);

    str volume = fullVolumeProcess(project_loc);
    str unitComplexity = fullUnitComplexityProcess(asts);
    str unitSize = fullUnitSizeProcess(project_loc);
    str duplication = fullDuplicationProcess(project_loc);

    println("============= Metrics =============");
    println("Volume rating          : <volume>");
    println("Unit Complexity rating : <unitComplexity>");
    println("Unit Size rating       : <unitSize>");
    println("Duplication rating     : <duplication>");

    // Maintainability aspects
    println("===== Maintainability Scores =====");
    str analysability = getAnalysabilityScore(volume, unitComplexity, duplication, unitSize);
    str unitTesting = "--"; // placeholder until testing/stability
    str changeability = getChangeabilityScore(unitComplexity, duplication);
    str testability = getTestabilityScore(unitComplexity, unitSize, unitTesting);
    str maintainability = getMaintainabilityScore(analysability, changeability, testability);

    println("Analysability Score   : <analysability>");
    println("Changeability Score   : <changeability>");
    println("Testability Score     : <testability>");
    println("Overall Maintainability: <maintainability>");
}



// ========================================= volume code ===================================================

// Count physical lines in a string
int countLOC(str source) {
    return (0 | it + 1 | /\n/ := source);
}

// Get total system LOC over all Java compilation units in the project
int getSystemLOC(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    int totalLOC = 0;

    for (loc f <- files(model.containment), isCompilationUnit(f)) {
        str src = readFile(f);
        totalLOC += countLOC(src);
    }

    return totalLOC;
}

// Map system LOC to a SIG-style rating
str getVolumeRating(int systemLOC) {
    if (systemLOC <= 10000) {
        return "++";
    } else if (systemLOC <= 50000) {
        return "+";
    } else if (systemLOC <= 200000) {
        return "o";
    } else if (systemLOC <= 1000000) {
        return "-";
    } else {
        return "--";
    }
}

// Full volume metric process
str fullVolumeProcess(loc projectLocation) {
    int sysLOC = getSystemLOC(projectLocation);
    return getVolumeRating(sysLOC);
}


// ========================================= unit complexity code ===================================================

//CC key
// 1-10 = without much rish
// 11-20 = moderate 
// 21-50 = high
// >50 = very high

// thanks stackoverflow: https://stackoverflow.com/questions/40064886/obtaining-cyclomatic-complexity
// I had to change the method slightly to fit my use case

// takes a method from an AST and calculates its cyclomatic complexity
int calcCC(Declaration impl) {
    int result = 1;
    visit (impl) {
        case \if(_,_) : result += 1;
        case \if(_,_,_) : result += 1;
        case \case(_) : result += 1;
        case \do(_,_) : result += 1;
        case \while(_,_) : result += 1;
        case \for(_,_,_) : result += 1;
        case \for(_,_,_,_) : result += 1;
        case \foreach(_,_,_) : result += 1;
        case \catch(_,_): result += 1;
        case \conditional(_,_,_): result += 1;
        // case \infix(_,"&&",_) : result += 1;
        // case \infix(_,"||",_) : result += 1;
    }
    return result;
}

list[int] getCcPercentages(list[Declaration] asts){
    list[int] cyclo_complexities = [calcCC(f) | f <- asts];

    int num_without_risk = 0;
    int num_moderate_risk = 0;
    int num_high_risk = 0;
    int num_very_high_risk = 0;

    for(int n <- cyclo_complexities){
        if(n >= 1 && n <= 10){
            num_without_risk = num_without_risk + 1;
        }else if (n >= 11 && n <= 20){
            num_moderate_risk = num_moderate_risk + 1;
        }else if (n >= 21 && n <= 50){
            num_high_risk = num_high_risk + 1;
        }else if (n >50){
            num_very_high_risk = num_very_high_risk + 1;
        }else{
            // something has gone horribly wrong
            throw ArithmeticException("a cc number is somehow out of range");
        }
    }
    int num_total = num_without_risk + num_moderate_risk + num_high_risk + num_very_high_risk;
    int percent_without_risk = 100 * num_without_risk / num_total; 
    int percent_moderate = 100 * num_moderate_risk / num_total;
    int percent_high = 100 * num_high_risk / num_total;
    int percent_very_high = 100 * num_very_high_risk / num_total;

    list[int] outputList = [percent_without_risk, percent_moderate, percent_high, percent_very_high];
    return outputList;
}

str getUnitComplexityRating(list[int] percentages){
    int percent_moderate = percentages[1];
    int percent_high = percentages[2];
    int percent_very_high = percentages[3];
    if(percent_moderate <= 25 && percent_high == 0 && percent_very_high == 0){
        return "++";
    }else if (percent_moderate <= 30 && percent_high <= 5 && percent_very_high == 0){
        return "+";
    }else if (percent_moderate <= 40 && percent_high <= 10 && percent_very_high == 0){
        return "o";
    }else if(percent_moderate <= 50 && percent_high <= 15 && percent_very_high <= 5){
        return "-";
    }else{
        return "--";
    }
}

str fullUnitComplexityProcess(list[Declaration] asts){
    list[int] ccPercentages = getCcPercentages(asts);
    return getUnitComplexityRating(ccPercentages);
}

// ========================================= unit size code ===================================================

// edited some code from the rascal website: https://www.rascal-mpl.org/docs/recipes/metrics/measuringjava/measuringmethods/ 
str fullUnitSizeProcess(loc projectLocation){
    list[str] allMethods = getAllMethods(projectLocation);
    map[int,int] riskProfile = getRiskProfile(allMethods);
    return getSizeRating(riskProfile);
}

int getLOCfromMethod(str method){
    return (0 | it + 1 | /\n/ := method);
}

list[str] getAllMethods(loc projectLocation){
    M3 model = createM3FromMavenProject(projectLocation);
    list[loc] methodLocations = toList(methods(model));
    list[str] methodsSourceCode = [];
    for (n <- methodLocations){
        methodsSourceCode = push(readFile(n), methodsSourceCode);
    }
    return methodsSourceCode;
}

// key: 0 = low risk, 1 = moderate risk, 2 = high risk, 3 = very high risk
int getRiskFromLOC(int linesOfCode){
    if(linesOfCode >=0 && linesOfCode <=15){
        return 0;
    }else if(linesOfCode >= 16 && linesOfCode <= 30){
        return 1;
    }else if(linesOfCode >= 31 && linesOfCode <= 60){
        return 2;
    }else if(linesOfCode >= 61){
        return 3;
    }else{// somehow the lines of code is out of range
        throw ArithmeticException("a lines of code count is somehow out of range");
    }
}

map[int,int] getRiskProfile(list[str] methods){
    // the first int is the risk level, the second is the number of methods that are at that risk level
    map[int,int] riskProfile = (0:0, 1:0, 2:0, 3:0);
    int currRisk = 0;
    for(method <- methods){
        currRisk = getRiskFromLOC(getLOCfromMethod(method));
        if(currRisk == 0){
            riskProfile = (0:(riskProfile[0] + 1), 1:riskProfile[1], 2:riskProfile[2], 3:riskProfile[3]);
        }else if(currRisk == 1){
            riskProfile = (0:(riskProfile[0]), 1:(riskProfile[1] + 1), 2:riskProfile[2], 3:riskProfile[3]);
        }else if(currRisk == 2){
            riskProfile = (0:(riskProfile[0]), 1:riskProfile[1], 2:(riskProfile[2] + 1), 3:riskProfile[3]);
        }else{
            riskProfile = (0:(riskProfile[0] + 1), 1:riskProfile[1], 2:riskProfile[2], 3:(riskProfile[3] + 1));
        }
    }
    return riskProfile;
}

// I can't find exact values for this, but the paper says they are similar to unit complexity
str getSizeRating(map[int, int] riskProfile){
    int num_methods = riskProfile[0] + riskProfile[1]+riskProfile[2]+riskProfile[3];

    int moderate_risk_percentage = riskProfile[1] * 100 / num_methods;
    int high_risk_percentage = riskProfile[2] * 100 / num_methods;
    int very_high_risk_percentage = riskProfile[3] * 100 / num_methods;

    if(moderate_risk_percentage <= 25 && high_risk_percentage == 0 && very_high_risk_percentage == 0){
        return "++";
    }else if (moderate_risk_percentage <= 30 && high_risk_percentage <= 5 && very_high_risk_percentage == 0){
        return "+";
    }else if (moderate_risk_percentage <= 40 && high_risk_percentage <= 10 && very_high_risk_percentage == 0){
        return "o";
    }else if(moderate_risk_percentage <= 50 && high_risk_percentage <= 15 && very_high_risk_percentage <= 5){
        return "-";
    }else{
        return "--";
    }
}


// ========================================= duplication code ==============================================

data LinePos = lp(loc file, int line); // 0-based line index within file

list[loc] getAllJavaFiles(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    return [f | f <- files(model.containment), isCompilationUnit(f)];
}

// Count total LOC over all Java files (same definition as Volume)
int getTotalProjectLOC(list[loc] files) {
    int totalLOC = 0;
    for (loc f <- files) {
        str src = readFile(f);
        totalLOC += countLOC(src);
    }
    return totalLOC;
}

// Compute the percentage of duplicated lines in 6-line blocks
real getDuplicationPercentage(loc projectLocation) {
    list[loc] javaFiles = getAllJavaFiles(projectLocation);
    int totalLOC = getTotalProjectLOC(javaFiles);

    // Map from 6-line block string -> list of positions where it occurs
    map[str, list[LinePos]] blockPositions = ();
    set[LinePos] duplicatedLines = {};

    for (loc f <- javaFiles) {
        str src = readFile(f);
        list[str] lines = split(src, "\n");
        int n = size(lines);

        // Walk all 6-line windows
        if(n > 6){
            for (int i <- [0 .. n - 6]) {
                str block = "<lines[i]>\n<lines[i+1]>\n<lines[i+2]>\n<lines[i+3]>\n<lines[i+4]>\n<lines[i+5]>";
                LinePos pos = lp(f, i);

                if (block in blockPositions) {
                    blockPositions[block] = blockPositions[block] + [pos];
                } else {
                    blockPositions[block] = [pos];
                }
            }
        }else if(n == 6){
            str block = "<lines[i]>\n<lines[i+1]>\n<lines[i+2]>\n<lines[i+3]>\n<lines[i+4]>\n<lines[i+5]>";
            LinePos pos = lp(f, i);

            if (block in blockPositions) {
                blockPositions[block] = blockPositions[block] + [pos];
            } else {
                blockPositions[block] = [pos];
            }
        }
        
    }

    // Collect all lines that are part of any duplicated 6-line block
    for (str block <- blockPositions) {
        list[LinePos] positions = blockPositions[block];
        if (size(positions) > 1) {
            for (LinePos p <- positions) {
                switch (p) {
                    case lp(loc f, int startLine):
                        // Mark the 6 lines of this block as duplicated
                        for (int k <- [0 .. 5]) {
                            duplicatedLines += { lp(f, startLine + k) };
                        }
                }
            }
        }
    }

    if (totalLOC == 0) {
        return 0.0;
    }

    real percentage = (size(duplicatedLines) * 100.0) / totalLOC;
    return percentage;
}

// Map duplication percentage to rating
str getDuplicationRating(real duplicationPercentage) {
    if (duplicationPercentage <= 2.0) {
        return "++";
    } else if (duplicationPercentage <= 5.0) {
        return "+";
    } else if (duplicationPercentage <= 10.0) {
        return "o";
    } else if (duplicationPercentage <= 20.0) {
        return "-";
    } else {
        return "--";
    }
}

// Full duplication process
str fullDuplicationProcess(loc projectLocation) {
    real dup = getDuplicationPercentage(projectLocation);
    return getDuplicationRating(dup);
}

// ========================================= analysability score ===========================================

str getAnalysabilityScore(str volume, str unitComplexity, str duplication, str unitSize) {
    map[str, real] ratingsKey = ("++":-2.0, "+":-1.0, "o":0.0, "-":1.0, "--":2.0);

    real numerical_result =
        (ratingsKey[volume]
       + ratingsKey[unitComplexity]
       + ratingsKey[duplication]
       + ratingsKey[unitSize]) / 4.0;

    if (numerical_result < -1.5) {
        return "++";
    } else if (numerical_result < -0.5) {
        return "+";
    } else if (numerical_result < 0.5) {
        return "o";
    } else if (numerical_result < 1.5) {
        return "-";
    } else {
        return "--";
    }
}


// ========================================== changeablty and testability ========================================

//these are just weighted averages of the previously calculated metrics.
// the ones that are used in each are indicated by the names of the input variables
// the input is the string representation of the score (ex "++" or "o")
// output is the unweighted average of the input scores

str getChangeabilityScore(str unitComplexity, str duplication){
    map[str, real] ratingsKey = ("++":-2.0, "+":-1.0, "o":0.0, "-":1.0, "--":2.0);

    real numerical_result = (ratingsKey[unitComplexity] + ratingsKey[duplication])/2.0;

    if(numerical_result < -1.5){
        return "++";
    }else if(numerical_result < -0.5){
        return "+";
    }else if(numerical_result < 0.5){
        return "o";
    }else if(numerical_result < 1.5){
        return "-";
    }else{
        return "--";
    }
} 

str getTestabilityScore(str unitComplexity, str unitSize, str unitTesting){
    map[str, real] ratingsKey = ("++":-2.0, "+":-1.0, "o":0.0, "-":1.0, "--":2.0);

    real numerical_result = (ratingsKey[unitComplexity] + ratingsKey[unitSize] + ratingsKey[unitTesting])/2.0;

    if(numerical_result < -1.5){
        return "++";
    }else if(numerical_result < -0.5){
        return "+";
    }else if(numerical_result < 0.5){
        return "o";
    }else if(numerical_result < 1.5){
        return "-";
    }else{
        return "--";
    }
} 

// class provided function
list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}

// ========================================= maintainability score =========================================

str getMaintainabilityScore(str analysability, str changeability, str testability) {
    map[str, real] ratingsKey = ("++":-2.0, "+":-1.0, "o":0.0, "-":1.0, "--":2.0);

    // add if/when stability is computed: + ratingsKey[stability] / 4.0
    real numerical_result =
        (ratingsKey[analysability]
       + ratingsKey[changeability]
       + ratingsKey[testability]) / 3.0;

    if (numerical_result < -1.5) {
        return "++";
    } else if (numerical_result < -0.5) {
        return "+";
    } else if (numerical_result < 0.5) {
        return "o";
    } else if (numerical_result < 1.5) {
        return "-";
    } else {
        return "--";
    }
}
