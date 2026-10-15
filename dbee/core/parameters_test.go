package core

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestNamedCompilation(t *testing.T) {
	cases := []struct {
		query, sql string
		names      []string
	}{
		{`SELECT :eventID, :name, :eventID`, `SELECT $1, $2, $1`, []string{"eventID", "name"}},
		{`SELECT :value::integer, ':literal', "a:param", $$:body;$$, $tag$:also;$tag$`, `SELECT $1::integer, ':literal', "a:param", $$:body;$$, $tag$:also;$tag$`, []string{"value"}},
		{"SELECT :x /* :skip /* :nested */ ; */ -- :comment\n;", "SELECT $1 /* :skip /* :nested */ ; */ -- :comment\n;", []string{"x"}},
		{`SELECT E'it\'s :literal', 'it''s :literal', :real`, `SELECT E'it\'s :literal', 'it''s :literal', $1`, []string{"real"}},
		{`SELECT foo$1, :x`, `SELECT foo$1, $1`, []string{"x"}},
		{`SELECT 1; SELECT ':literal';`, `SELECT 1; SELECT ':literal';`, []string{}},
		{`SELECT :x; -- trailing comment`, `SELECT $1; -- trailing comment`, []string{"x"}},
	}
	for _, tc := range cases {
		t.Run(tc.query, func(t *testing.T) {
			plan, err := CompileNamed(tc.query)
			if err != nil {
				t.Fatal(err)
			}
			if plan.SQL != tc.sql || !reflect.DeepEqual(plan.Names, tc.names) {
				t.Fatalf("got %#v", plan)
			}
		})
	}
}

func TestNamedInvalidQueries(t *testing.T) {
	for _, query := range []string{`SELECT :x; SELECT :y`, `SELECT $1, :x`, `SELECT ':x`, `SELECT /* :x`, `SELECT $tag$:x`} {
		if _, err := CompileNamed(query); err == nil {
			t.Errorf("expected rejection: %s", query)
		}
	}
	var query strings.Builder
	query.WriteString("SELECT ")
	for i := 0; i < 65535; i++ {
		if i > 0 {
			query.WriteByte(',')
		}
		fmt.Fprintf(&query, ":p%d", i)
	}
	if _, err := CompileNamed(query.String()); err != nil {
		t.Fatal(err)
	}
	query.WriteString(",:too_many")
	if _, err := CompileNamed(query.String()); err == nil {
		t.Fatal("65536 parameters should fail")
	}
}

type unboundTestDriver struct{}

func (*unboundTestDriver) Query(context.Context, string) (ResultStream, error) {
	return nil, errors.New("unbound")
}
func (*unboundTestDriver) Structure() ([]*Structure, error)         { return nil, nil }
func (*unboundTestDriver) Columns(*TableOptions) ([]*Column, error) { return nil, nil }
func (*unboundTestDriver) Close()                                   {}

type boundTestDriver struct {
	unboundTestDriver
	query string
	args  []any
}

func (d *boundTestDriver) QueryParams(_ context.Context, query string, args []any) (ResultStream, error) {
	d.query, d.args = query, args
	return nil, errors.New("finished test execution")
}

func TestBoundExecutionSeparatesValues(t *testing.T) {
	driver := &boundTestDriver{}
	connection := &Connection{driver: driver}
	query := `SELECT :text::text, :empty::text, :nothing::text, :big::numeric, :text`
	values := map[string]ParameterValue{
		"text":  {Text: "O'Reilly \\ newline\n; SELECT 'not executed'"},
		"empty": {Text: ""}, "nothing": {Null: true}, "big": {Text: "900719925474099312345.6789"},
	}
	call, err := connection.ExecuteBound(query, values, func(CallState, *Call) {})
	if err != nil {
		t.Fatal(err)
	}
	select {
	case <-call.Done():
	case <-time.After(3 * time.Second):
		t.Fatal("timeout")
	}
	want := []any{values["text"].Text, "", nil, values["big"].Text}
	if !reflect.DeepEqual(driver.args, want) {
		t.Fatalf("arguments: %#v", driver.args)
	}
	if driver.query != `SELECT $1::text, $2::text, $3::text, $4::numeric, $1` {
		t.Fatal(driver.query)
	}
	data, _ := json.Marshal(call)
	if call.GetQuery() != query || strings.Contains(string(data), "O'Reilly") {
		t.Fatal("history changed or retained values")
	}
}

func TestBoundValidation(t *testing.T) {
	connection := &Connection{driver: &boundTestDriver{}}
	for _, values := range []map[string]ParameterValue{{}, {"x": {}, "extra": {}}} {
		if _, err := connection.ExecuteBound("SELECT :x", values, func(CallState, *Call) {}); err == nil {
			t.Fatal("invalid values accepted")
		}
	}
	unsupported := &Connection{driver: &unboundTestDriver{}}
	if _, err := unsupported.ParameterNames("SELECT :x"); err == nil {
		t.Fatal("unsupported driver accepted binding")
	}
	if names, err := unsupported.ParameterNames("SELECT 1; SELECT 2"); err != nil || len(names) != 0 {
		t.Fatal("plain batches must remain supported")
	}
}
