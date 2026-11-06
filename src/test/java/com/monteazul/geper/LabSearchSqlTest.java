package com.monteazul.geper;

import com.monteazul.geper.lab.LabSearchRepository;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * GROUP 3 (optional characterization) - documents the SECURITY-LAB
 * JAVA-SQLI-01 anti-pattern at the string level, offline and with no
 * database. It proves that the user term is concatenated verbatim into the
 * SQL (the defect), WITHOUT asserting that the application is "safe".
 */
class LabSearchSqlTest {

    // buildSql() does not touch the datasource, so a null one is fine here.
    private final LabSearchRepository repo = new LabSearchRepository(null);

    @Test
    void userInputIsConcatenatedVerbatimIntoSql() {
        String sql = repo.buildSql("mora");
        assertThat(sql).contains("LIKE UPPER('%mora%')");
    }

    @Test
    void injectionMetacharactersAreNotNeutralised() {
        // A quote in the term lands un-escaped inside the SQL text: the
        // hallmark of the injection flaw this lab demonstrates.
        String sql = repo.buildSql("x') OR 1=1 --");
        assertThat(sql).contains("x') OR 1=1 --");
        assertThat(sql).doesNotContain("''"); // no escaping/parameterisation applied
    }
}
