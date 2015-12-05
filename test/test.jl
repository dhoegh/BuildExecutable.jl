import DataFrames # Even if using was used here full qualification of the functions in Base.Test and DataFrames is needed
import Base.Test
function main()
    df = DataFrames.@data([3, 2, 5, 4])
    Base.Test.@test  maximum(df) == 5
    println("It works")
end