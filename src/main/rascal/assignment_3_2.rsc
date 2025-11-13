module assignment_3_2

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import List;
import Set;
import String;

int main(){
    asts = getASTs(|project://smallsql0.21_src/|);
    int num_occurences;
    list[str] variables = [];
    tuple[int, list[str]] return_val = mostOccurringVariables(asts);
    num_occurences = return_val[0];
    variables = variables + return_val[1];
    println("the most frequent variable(s) occur <num_occurences> times.");
    println("the variables with the highest occurcences are: ");
    for(int n <- [0..(size(variables)-1)])
        println(variables[n]);
    return 0;
}


tuple[int, list[str]] mostOccurringVariables(list[Declaration] asts){
// TODO: Create this function
    list[str] variables = [];
    list[int] counts = [];
    visit(asts){
        case \variable(\id(str name), _): if(indexOf(variables, name) == -1){
            variables = variables + [name];
            counts = counts + [1];
            }else{
            counts[indexOf(variables, name)] = counts[indexOf(variables, name)] + 1;
            }
        case \variable(\id(str name), _, _): if(indexOf(variables, name) == -1){
            variables = variables + [name];
            counts = counts + [1];
            }else{
            counts[indexOf(variables, name)] = counts[indexOf(variables, name)] + 1;
            }
        case \fieldAccess(\id(str name)):if(indexOf(variables, name) == -1){
            variables = variables + [name];
            counts = counts + [1];
            }else{
            counts[indexOf(variables, name)] = counts[indexOf(variables, name)] + 1;
            }
        case \fieldAccess(_, \id(str name)):if(indexOf(variables, name) == -1){
            variables = variables + [name];
            counts = counts + [1];
            }else{
            counts[indexOf(variables, name)] = counts[indexOf(variables, name)] + 1;
            }
        case \parameter(_, _, \id(str name), _):if(indexOf(variables, name) == -1){
            variables = variables + [name];
            counts = counts + [1];
            }else{
            counts[indexOf(variables, name)] = counts[indexOf(variables, name)] + 1;
            }
        case \vararg(_, _, \id(str name)):if(indexOf(variables, name) == -1){
            variables = variables + [name];
            counts = counts + [1];
            }else{
            counts[indexOf(variables, name)] = counts[indexOf(variables, name)] + 1;
            }
    }
    int largest_num = max(counts);
    list[int] indexes_of_max = [];
    for(int i <- [0..(size(counts) -1)]){
        if(counts[i] == largest_num){
            indexes_of_max = indexes_of_max + [i];
        }
    }
    list[str] var_names = [];
    // do i need a special case for if there's just one?
    for(int i <- [0..(size(indexes_of_max) - 1)]){
        var_names = var_names + [variables[indexes_of_max[i]]];
    }
    return <largest_num, var_names>; // change logic
}

// class provided function
list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}