package com.monteazul.geper;

import com.monteazul.geper.lab.LabSearchRepository;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * GROUP 3 (characterization) - documents the JAVA-SQLI-01 remediation at the
 * string level, offline and with no database. It proves that the user term
 * is NOT concatenated into the SQL text; the statement uses a bind variable
 * (the fix for the previous anti-pattern).
 */
class LabSearchSqlTest {

    // buildSql() does not touch the datasource, so a null one is fine here.
    private final LabSearchRepository repo = new LabSearchRepository(null);

    @Test
    void userInputIsNotConcatenatedIntoSql() {
        String sql = repo.buildSql("mora");
        assertThat(sql).contains("LIKE UPPER(?)");
        assertThat(sql).doesNotContain("mora");
    }

    @Test
    void injectionMetacharactersDoNotAlterTheSqlTemplate() {
        // The term is never concatenated, so injection metacharacters have
        // no effect on the SQL template regardless of their content.
        String sql = repo.buildSql("x') OR 1=1 --");
        assertThat(sql).doesNotContain("x') OR 1=1 --");
        assertThat(sql).contains("LIKE UPPER(?)");
    }
}

