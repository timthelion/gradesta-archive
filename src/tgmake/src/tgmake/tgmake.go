/*
This is the single file source code for the tgmake binary, parser, sorter, well, everything.

tgmake is a small simple utility for preforming a topological sort on a directed acyclic text graph. It assumes that node 0 is the bottom. If there are any dependencies on node 0 or any cycles in the program will return an error.

*/

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"os"
)

/*
  Types
*/

func main() {
	if len(os.Args) > 1 {
		log.Fatalf(`tgmake is a small simple utility for preforming a topological sort on a directed acyclic text graph. It assumes that node 0 is the bottom. If there are any dependencies on node 0 or any cycles in the program will return an error. It will sort your graph in a deterministic order as textgraph edges are ordered. It starts with the edges going out from node 0 and will look down the first edge untill it finds an independent node, always following the first edge first.
tggraph takes no arguments. Instead, pipe it your textgraph to stdin and your sorted text graph will be printed to stdout.`)
	}
	/*
		Parse
	*/
	scanner := bufio.NewScanner(os.Stdin)
	graph := make(map[int64]*Node)
	for scanner.Scan() {
		var json_node JSONNode
		line := scanner.Text()
		if line[0] == '#'{
			continue
		}
		if err := json.Unmarshal([]byte(line), &json_node); err != nil {
			log.Fatal(err)
		}
		streets := []Street{}
		var street Street
		for _, raw_json_street := range json_node.streets {
			if err := json.Unmarshal(raw_json_street, &street); err != nil {
				log.Fatal(err)
			}
			streets = append(streets, street)
		}
		graph[json_node.id] = &Node{id: json_node.id, text: json_node.text, streets: streets, sorted: false, generation: 0, origional_json: line}
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	/*
	   Sort
	*/
	n, generation := int64(0), int64(1)
L:
	for {
		if graph[n].generation == generation {
			log.Fatalf("Cycle detected.")
		}
		graph[n].generation = generation
		for _,street := range graph[n].streets {
			if !graph[street.destination].sorted {
				n = street.destination
				continue L
			}
		}
		fmt.Println(graph[n].origional_json)
		generation++
		graph[n].sorted = true
		if n == 0 {
			return
		}
		n = 0
	}
}

type JSONNode struct {
	id      int64
	text    string
	streets []json.RawMessage
}

type Node struct {
	id             int64
	text           string
	origional_json string
	streets        []Street
	sorted         bool
	generation     int64
}

type Street struct {
	name        string
	destination int64
}

func (b *JSONNode) UnmarshalJSON(buf []byte) error {
	// THANKS! http://eagain.net/articles/go-json-array-to-struct/
	tmp := []interface{}{&b.id, &b.text, &b.streets}
	wantLen := len(tmp)
	if err := json.Unmarshal(buf, &tmp); err != nil {
		return err
	}
	if g, e := len(tmp), wantLen; g != e {
		return fmt.Errorf("wrong number of fields in Block: %d != %d", g, e)
	}
	return nil
}

func (s *Street) UnmarshalJSON(buf []byte) error {
	// THANKS! http://eagain.net/articles/go-json-array-to-struct/
	tmp := []interface{}{&s.name, &s.destination}
	wantLen := len(tmp)
	if err := json.Unmarshal(buf, &tmp); err != nil {
		return err
	}
	if g, e := len(tmp), wantLen; g != e {
		return fmt.Errorf("wrong number of fields in Street: %d != %d", g, e)
	}
	return nil
}
