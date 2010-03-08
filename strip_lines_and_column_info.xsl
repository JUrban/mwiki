<?xml version='1.0' encoding='UTF-8'?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml"/>

  <xsl:template match="processing-instruction(&apos;xml-stylesheet&apos;)"/>

  <xsl:template match="@line"/>

  <xsl:template match="@col"/>

  <xsl:template match="@href"/>

  <xsl:template match="@mizfiles"/>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
