defmodule ElixirSnippets.Mnesia do
  @moduledoc "A small example of how to setup and use Mnesia. 
    See http://learnyousomeerlang.com/mnesia and http://erlang.org/doc/man/mnesia.html
    for more information."
  
  require Record
  import Record

  # An understanding of how records are internally represented
  # will help (http://erlang.org/doc/reference_manual/records.html)
  # understand how Mnesia takes advantage of them.
  # See record_representation/0 for an example.
  defrecord :my_record, id: nil, name: nil, number: nil

  # same name as record, simplifies using mnesia
  @tab :my_record 

  alias :mnesia, as: Mnesia

  def setup do
    nodes = [Node.self()|Node.list()]

    #need to create schema before starting mnesia
    Mnesia.create_schema(nodes)
    Application.start(:mnesia)
    
    Mnesia.create_table(@tab,
      attributes: my_record_fields(), #first element is primary key
      disc_copies: nodes 
    )
  end

  def my_record_fields do
    #returns field names from the my_record record
    Keyword.keys(my_record(my_record()))
  end

  def add_element(id, name, number) do
    fun = fn() ->
      # tab is first element from my_record (which is my_record)
      Mnesia.write(my_record(id: id, name: name, number: number))
    end
    Mnesia.activity(:transaction, fun)
  end

  def find_element(id) do
    fun = fn() -> Mnesia.read(@tab, id) end
    Mnesia.activity(:transaction, fun)
  end

  def update_element(id, number) do
    fun = fn() ->
      [old_element|_] = Mnesia.read(@tab, id)
      new_element = my_record(old_element, number: number)
      Mnesia.write(new_element)
    end
    Mnesia.activity(:transaction, fun)
  end

  def delete_element(id) do
    fun = fn() -> Mnesia.delete({@tab, id}) end
    Mnesia.activity(:transaction, fun)      
  end

  def match_element(spec) do
    fun = fn() -> Mnesia.match_object(spec) end
    Mnesia.activity(:transaction, fun)
  end

  def select_element_with_name_1 do
    import Ex2ms
    # :ets.fun2ms doesn't work. This is an alternative, doesn't seem to accept variables in the
    # expression though.
    match_spec = fun do {record, id, name, number} when name == 1 -> {record, id, name, number} end
    fun = fn() -> Mnesia.select(@tab, match_spec) end
    Mnesia.activity(:transaction, fun)
  end

  def find_element_by_name(find_name) do
    foldl = fn({_,_,name,_} = record, acc) when name == find_name -> [record|acc]
              (record, acc) -> acc
    end
    fun = fn() -> Mnesia.foldl(foldl, [], :my_record) end
    Mnesia.activity(:transaction, fun)
  end

  def record_representation do
    #note how record name is first element
    {:my_record, 123, "name", 321} = my_record(id: 123, name: "name", number: 321)
  end
  
end

defmodule ElixirSnippets.MnesiaDemo do
  require ElixirSnippets.Mnesia
  import ElixirSnippets.Mnesia
  
  def run do
    ElixirSnippets.Mnesia.setup()
    Process.sleep(100)

    #add
    ElixirSnippets.Mnesia.add_element(123, "name", 321)

    #read
    [my_record(id: 123, name: "name", number: 321)] =
      ElixirSnippets.Mnesia.find_element(123)

    #update
    ElixirSnippets.Mnesia.update_element(123, 111)
    [my_record(id: 123, name: "name", number: 111)] =
      ElixirSnippets.Mnesia.find_element(123)

    [my_record(id: 123, name: "name", number: 111)] =
      ElixirSnippets.Mnesia.match_record({:my_record, :_, :_, 111})
    
    #delete
    ElixirSnippets.Mnesia.delete_element(123)
    [] = ElixirSnippets.Mnesia.find_element(123) 
  end
end
