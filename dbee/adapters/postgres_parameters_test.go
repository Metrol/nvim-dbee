package adapters

import (
	"context"
	"github.com/DATA-DOG/go-sqlmock"
	"github.com/kndndrj/nvim-dbee/dbee/core/builders"
	"regexp"
	"testing"
)

func TestPostgresBoundQuery(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	driver := &postgresDriver{c: builders.NewClient(db)}
	query := `SELECT $1::text, $2::text`
	mock.ExpectQuery(regexp.QuoteMeta(query)).WithArgs("O'Reilly", nil).
		WillReturnRows(sqlmock.NewRows([]string{"name", "nothing"}).AddRow("O'Reilly", nil))
	result, err := driver.QueryParams(context.Background(), query, []any{"O'Reilly", nil})
	if err != nil {
		t.Fatal(err)
	}
	defer result.Close()
	if !result.HasNext() {
		t.Fatal("missing row")
	}
	row, err := result.Next()
	if err != nil || row[0] != "O'Reilly" || row[1] != nil {
		t.Fatalf("row=%#v err=%v", row, err)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestPostgresBoundUpdate(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	driver := &postgresDriver{c: builders.NewClient(db)}
	query := `UPDATE people SET name=$1 WHERE id=$2`
	mock.ExpectExec(regexp.QuoteMeta(query)).WithArgs("O'Reilly", "42").WillReturnResult(sqlmock.NewResult(0, 1))
	result, err := driver.QueryParams(context.Background(), query, []any{"O'Reilly", "42"})
	if err != nil {
		t.Fatal(err)
	}
	defer result.Close()
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
