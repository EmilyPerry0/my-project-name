module assignment_3_1

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import List;
import Set;
import String;

int main(){
    asts = getASTs(|project://smallsql0.21_src/|);
    int num_for_loops = getNumberOfForLoops(asts);
    println("number of for loops: <num_for_loops>");
    return 0;
}

int getNumberOfForLoops(list[Declaration] asts){
// TODO: Create this function
    int for_loops = 0;
    visit(asts){
        case \for(_, _, _): for_loops += 1;
        case \for(_, _, _, _): for_loops += 1;
        case \foreach(_, _, _): for_loops += 1;
    }
    return for_loops;
}

// class provided function
list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}