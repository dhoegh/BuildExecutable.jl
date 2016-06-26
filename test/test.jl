import Base.Test # Even if using was used here full qualification of the functions in Base.Test is needed, or if any other module was used.
import JSON
function main()
    s = "{\"number\" : 5, \"arr\" : [3, 2, 5, 4]}"
    j = JSON.parse(s)
    Base.Test.@test  maximum(j["arr"]) == j["number"]
    println(join(ARGS,","))
    println("It works")
end
