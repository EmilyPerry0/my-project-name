module Main

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import List;
import Set;
import String;

int main() {
    println("Hello, World!");
    asts = getASTs(|project://smallsql0.21_src/|);
    other_var = getNumberOfInterfaces(asts);
    println("number of interfaces: <other_var>");
    return 0;
}

list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}

int getNumberOfInterfaces(list[Declaration] asts){
    int interfaces = 0;
    visit(asts){
        case \interface(_, _, _, _, _, _): interfaces += 1;
    }
    return interfaces;
}